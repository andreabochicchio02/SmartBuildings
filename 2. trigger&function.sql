DROP TRIGGER IF EXISTS InMattone;

DELIMITER $$
CREATE TRIGGER InMattone
BEFORE INSERT ON mattone
FOR EACH ROW
BEGIN
	IF(NEW.Riempimento = 'pieno' AND NEW.Alveolatura IS NOT NULL) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Il mattone non può avere alveolatura perchè è pieno';
    END IF;
    
    IF(NEW.Riempimento <> 'pieno' AND NEW.Alveolatura IS NULL) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "E' necessario inserire il tipo di alveolatura";
    END IF;
END $$
DELIMITER ;
#-----------------------------------------------------------------------------------------



DROP TRIGGER IF EXISTS InPassaggio;

DELIMITER $$
CREATE TRIGGER InPassaggio
BEFORE INSERT ON passaggio
FOR EACH ROW
BEGIN
	DECLARE edificio INT DEFAULT 0;
    
	SELECT COUNT(*) INTO edificio
    FROM Vano V
    WHERE V.Edificio = NEW.edificio
		AND (
			V.NumeroVano = NEW.Vano1
            OR V.NumeroVano = NEW.Vano2
        );
        
	IF (edificio <> 2) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'I vani devono appartenere allo stesso edificio';
    END IF;
    
		
END $$
DELIMITER ;
#------------------------------------------------------------------------------------------


DROP TRIGGER IF EXISTS InProgettoEdilizio;

DELIMITER $$
CREATE TRIGGER InProgettoEdilizio
BEFORE INSERT ON progettoedilizio
FOR EACH ROW
BEGIN
	DECLARE errore INT DEFAULT 1;
    
	IF(	NEW.DataPresentazione < NEW.DataApprovazione
		AND NEW.DataApprovazione < NEW.DataInizio
        AND NEW.DataInizio < NEW.StimaDataFine) THEN
        SET errore = 0;
    END IF;
    
    IF(errore = 1) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'I valori delle varie fasi temporali non sono coerenti';
    END IF;
END $$
DELIMITER ;
#------------------------------------------------------------------------------------------


DROP TRIGGER IF EXISTS InStadioAvanzamento;

DELIMITER $$
CREATE TRIGGER InStadioAvanzamento
BEFORE INSERT ON stadioavanzamento
FOR EACH ROW
BEGIN
	DECLARE errore INT DEFAULT 1;
    DECLARE lavori_in_esecuzione INT DEFAULT 0;
    DECLARE costo_lavoro INT DEFAULT 0;
    DECLARE data_progetto DATE;
    
	
	IF(	NEW.DataInizio < NEW.StimaTermine) THEN
        SET errore = 0;
    END IF;
    
    IF(errore = 1) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'I valori delle varie fasi temporali non sono coerenti';
    END IF;
    
    #------------------------------------------------------------
    
    SET errore = 0;
    IF(NEW.DataCompletamento IS NOT NULL AND NEW.DataInizio > NEW.DataCompletamento) THEN
        SET errore = 1;
    END IF;
    
    IF(errore = 1) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'I valori delle varie fasi temporali non sono coerenti';
    END IF;
    #------------------------------------------------------------
    
    SELECT COUNT(*) INTO lavori_in_esecuzione
    FROM Lavoro L
    WHERE L.StadioAvanzamento = NEW.ID
		AND L.Termine IS NULL;
	
	IF(lavori_in_esecuzione <> 0 AND NEW.DataCompletamento IS NOT NULL) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Stadio di avanzamento ancora in esecuzione";
	END IF;
 
	#------------------------------------------------------------

	SET errore = 0;
    IF(NEW.DataCompletamento IS NULL AND NEW.CostoFinale IS NOT NULL) THEN
        SET errore = 1;
    END IF;
    
    IF(errore = 1) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Non è possibile determinare il costo finale perchè il lavoro non è ancora concluso';
    END IF;
    
    #------------------------------------------------------------
    
    SELECT IFNULL(SUM(L.Costo), 1) INTO costo_lavoro
    FROM Lavoro L
    WHERE L.StadioAvanzamento = NEW.ID;
    
	IF(NEW.DataCompletamento = NEW.StimaTermine) THEN
		SET NEW.CostoFinale = costo_lavoro;
	ELSEIF(NEW.DataCompletamento > NEW.StimaTermine) THEN
		SET NEW.CostoFinale = 
			costo_lavoro + (0.05*costo_lavoro*(NEW.DataCompletamento - NEW.StimaTermine));
	END IF;
    
    #------------------------------------------------------------
    
    SELECT DataInizio INTO data_progetto
    FROM progettoedilizio
    WHERE Codice = NEW.ProgettoEdilizioCod
		AND CodiceCatastaleComune = NEW.ProgettoEdilizioComune;
        
	IF(NEW.DataInizio < data_progetto) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Lo stadio di avanzamento inizia prima del progetto edilizio';
    END IF;
    
END $$
DELIMITER ;
#------------------------------------------------------------------------------------------


DROP TRIGGER IF EXISTS InLavoro;

DELIMITER $$
CREATE TRIGGER InLavoro
BEFORE INSERT ON lavoro
FOR EACH ROW
BEGIN
	DECLARE data_stadio DATE;
    
	IF(	NEW.Inizio > NEW.Termine) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'I valori delle fasi temporali non sono coerenti';
    END IF;
    
    #------------------------------------------------------------
    
    SELECT DataInizio INTO data_stadio
    FROM stadioavanzamento
    WHERE ID = NEW.StadioAvanzamento;
        
	IF(NEW.Inizio < data_stadio) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Il lavoro inizia prima dello stadio di avanzamento';
    END IF;
    
END $$
DELIMITER ;
#------------------------------------------------------------------------------------------


DROP TRIGGER IF EXISTS InMura;

DELIMITER $$
CREATE TRIGGER InMura
BEFORE INSERT ON mura
FOR EACH ROW
BEGIN
	DECLARE errore INT DEFAULT 0;
    
	IF(	NEW.SSI2 IS NOT NULL AND NEW.SSI1 IS NULL) THEN
        SET errore = 1;
	ELSEIF(NEW.SSI3 IS NOT NULL AND NEW.SSI2 IS NULL) THEN
        SET errore = 1;
	ELSEIF(NEW.SSI4 IS NOT NULL AND NEW.SSI3 IS NULL) THEN
        SET errore = 1;
    END IF;
    
    IF(errore = 1) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Errore nell'inserimento degli strati";
    END IF;
END $$
DELIMITER ;
#------------------------------------------------------------------------------------------


DROP TRIGGER IF EXISTS InCalendario;

DELIMITER $$
CREATE TRIGGER InCalendario
BEFORE INSERT ON calendario
FOR EACH ROW
BEGIN
	DECLARE obbligo_superv INT DEFAULT 0; 
    DECLARE supervisore_valido INT DEFAULT 0; 
    DECLARE lavoratori_coordinabili INT DEFAULT 0;
    DECLARE attuali_lavorori_capocantiere INT DEFAULT 0;
    DECLARE lavoratori_attuali INT DEFAULT 0;
    DECLARE totale_operai INT DEFAULT 0;
    DECLARE durata_turno INT DEFAULT 0;
    DECLARE mansione_esistente INT DEFAULT 0;
            
	SELECT COUNT(*) INTO obbligo_superv
    FROM lavoratore L
    WHERE L.Matricola = NEW.Lavoratore
		AND L.Ruolo <> 'capocantiere'
        AND L.Ruolo <> 'responsabile';
    
	SELECT COUNT(*) INTO supervisore_valido
    FROM lavoratore L
    WHERE L.Matricola = NEW.IdSupervisore
		AND L.Ruolo = 'capocantiere';
	
	IF(obbligo_superv = 1 AND NEW.IdSupervisore IS NULL) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Errore nell'inserimento in calendario";
    END IF;
    
    IF(obbligo_superv = 0 AND NEW.IdSupervisore IS NOT NULL) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Errore nell'inserimento in calendario";
    END IF;
    
    IF(supervisore_valido = 0 AND NEW.IdSupervisore IS NOT NULL) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Errore nell'inserimento in calendario";
    END IF;
    
    #------------------------------------------------------------
    
    SELECT IF (((YEAR(CURRENT_DATE) - L.AnnoInizio)/4) < 3, 3,  ((YEAR(CURRENT_DATE) - L.AnnoInizio)/4))  INTO lavoratori_coordinabili
    FROM Lavoratore L
    WHERE L.Matricola = NEW.IdSupervisore;
    
    SELECT COUNT(*) INTO totale_operai
    FROM Lavoratore
    WHERE Ruolo <> 'capocantiere'
		AND Ruolo <> 'responsabile';
    
    SET durata_turno = NEW.Durata;
	WHILE (durata_turno > 0) DO
    
			SELECT COUNT(*) INTO lavoratori_attuali 
			FROM calendario C
			WHERE DATE_FORMAT(C.GiornoEdOrario, '%Y|%M|%d') = DATE_FORMAT(NEW.GiornoEdOrario, '%Y|%M|%d') 
				AND HOUR(C.GiornoEdOrario) = HOUR(NEW.GiornoEdOrario) + durata_turno - 1;
                
			IF((lavoratori_attuali + 1) > 0.8*(totale_operai)) THEN
				SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = "Superato limite massimo lavoratori";
			END IF;
            
            SELECT COUNT(*) INTO attuali_lavorori_capocantiere 
			FROM calendario C
			WHERE DATE_FORMAT(C.GiornoEdOrario, '%Y|%M|%d') = DATE_FORMAT(NEW.GiornoEdOrario, '%Y|%M|%d') 
				AND HOUR(NEW.GiornoEdOrario) + durata_turno - 1 = HOUR(C.GiornoEdOrario)
                AND C.IdSupervisore = NEW.IDSupervisore;
            
            IF(NEW.IDSupervisore IS NOT NULL AND (attuali_lavorori_capocantiere + 1) > (lavoratori_coordinabili)) THEN
				SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = "Superato limite massimo lavoratori per un capocantiere";
			END IF;
            
            SET durata_turno = durata_turno - 1;
    END WHILE ;
    
    #------------------------------------------------------------
    
    SELECT COUNT(*) INTO mansione_esistente
    FROM Lavoro L
		INNER JOIN
        Manodopera M ON (
				L.Nome = M.Lavoro
                AND L.StadioAvanzamento = M.StadioAvanzamento
                )
    WHERE L.Nome = NEW.Mansione
		AND L.Inizio <= NEW.GiornoEdOrario
        AND M.Lavoratore = NEW.Lavoratore;
        
	IF(mansione_esistente = 0) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Lavoro inesistente per questo lavoratore";
    END IF;
        
END $$
DELIMITER ;
#------------------------------------------------------------------------------------------


DROP TRIGGER IF EXISTS InSensore;

DELIMITER $$
CREATE TRIGGER InSensore
BEFORE INSERT ON sensore
FOR EACH ROW
BEGIN
	DECLARE errore INT DEFAULT 1; 
    
	IF(NEW.Edificio IS NOT NULL 
		AND NEW.Vano IS NULL AND NEW.EdificioVano IS NULL AND NEW.mura IS NULL) THEN 
        SET errore = 0;
	ELSEIF (NEW.Vano IS NOT NULL AND NEW.EdificioVano IS NOT NULL
				AND NEW.Edificio IS NULL AND NEW.mura IS NULL) THEN 
		SET errore = 0;
	ELSEIF (NEW.Mura IS NOT NULL 
				AND NEW.Vano IS NULL AND NEW.EdificioVano IS NULL AND NEW.Edificio IS NULL) THEN 
		SET errore = 0;
	END IF;
	
    IF(errore = 1) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Sensore posizionato scorrettamente";
    END IF;
    
END $$
DELIMITER ;
#------------------------------------------------------------------------------------------


DROP TRIGGER IF EXISTS InMisurazione;

DELIMITER $$
CREATE TRIGGER InMisurazione
BEFORE INSERT ON misurazione
FOR EACH ROW
BEGIN
	DECLARE soglia_sensore INT;
     DECLARE sensori_mensili INT DEFAULT 0;
    
    SELECT S.Soglia INTO soglia_sensore
    FROM sensore S
    WHERE S.ID = NEW.Sensore;

	IF(NEW.Intensita > soglia_sensore) THEN
		SET NEW.Alert = TRUE;
	END IF;
		
	IF(NEW.Alert IS TRUE AND NEW.Intensita <= soglia_sensore) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "La misurazione non supera la soglia";
	END IF;

	#------------------------------------------------------------
    
    SELECT COUNT(*) INTO sensori_mensili
    FROM sensore S
    WHERE S.ID = NEW.sensore
		AND (
			S.Tipo = "giroscopio"
            OR S.Tipo = "accelerometro"
			OR S.Tipo = "posizione"
			);
        
	IF(sensori_mensili = 1 AND (DAY(NEW.DataRilevamento) <> 1 AND NEW.Intensita < soglia_sensore)) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Non è necessario archiviare la misurazione";
	END IF;

END $$
DELIMITER ;
#------------------------------------------------------------------------------------------

DROP TRIGGER IF EXISTS UpStadioAvanzamento;

DELIMITER $$
CREATE TRIGGER UpStadioAvanzamento
BEFORE UPDATE ON stadioavanzamento
FOR EACH ROW
BEGIN
	DECLARE costo_lavoro INT DEFAULT 0;
    DECLARE errore INT DEFAULT 0;
    
    SELECT COUNT(*) INTO errore
    FROM Lavoro L
    WHERE L.StadioAvanzamento = NEW.ID
		AND L.Termine IS NULL;
        
	IF(errore <> 0 AND NEW.DataCompletamento IS NOT NULL) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Lavori non acora completati";
	END IF;
    
    #------------------------------------------------------------
    
    SELECT SUM(L.Costo) INTO costo_lavoro
    FROM Lavoro L
    WHERE L.StadioAvanzamento = NEW.ID;
    
    IF(NEW.DataCompletamento = OLD.StimaTermine) THEN
		SET NEW.CostoFinale = costo_effettivo;
    ELSEIF(NEW.DataCompletamento > OLD.StimaTermine) THEN
		SET NEW.CostoFinale = 
			costo_lavoro + (0.05*costo_lavoro*(NEW.DataCompletamento - OLD.StimaTermine));
	END IF;
    
END $$
DELIMITER ;
#------------------------------------------------------------------------------------------


DROP TRIGGER IF EXISTS InVano;

DELIMITER $$
CREATE TRIGGER InVano
BEFORE INSERT ON Vano
FOR EACH ROW
BEGIN
	DECLARE esiste_piano INT DEFAULT 0;
    
	SELECT COUNT(*) INTO esiste_piano
    FROM Pianta
    WHERE Edificio = NEW.Edificio
		AND Piano = NEW.Piano;
        
	IF(esiste_piano = 0) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Non è presenta la pianta del piano inserito";
	END IF;
    
END $$
DELIMITER ;
#------------------------------------------------------------------------------------------


DROP TRIGGER IF EXISTS InEdificio;

DELIMITER $$
CREATE TRIGGER InEdificio
BEFORE INSERT ON edificio
FOR EACH ROW
BEGIN
	DECLARE errore INT DEFAULT 0;
    
    SELECT COUNT(*) INTO errore
    FROM edificio E
    WHERE E.Comune = NEW.Comune
		AND E.Foglio = NEW.Foglio
        AND E.Particella = NEW.Particella
        AND E.Sub = NEW.Sub;
        
	IF(errore = 1) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "Edifcio già esistente";
	END IF;
    
END $$
DELIMITER ;
#------------------------------------------------------------------------------------------


DROP TRIGGER IF EXISTS InAccesso;

DELIMITER $$
CREATE TRIGGER InAccesso
BEFORE INSERT ON accesso
FOR EACH ROW
BEGIN
	DECLARE esiste_piano INT DEFAULT 0;
    
    IF(NEW.Classificazione = 'portafinestra' AND NEW.PuntoCardinale IS NULL) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = "E' necessario inserire il punto cardinale";
    END IF;
    
END $$
DELIMITER ;
#------------------------------------------------------------------------------------------





#--------------------------FUNCTIONS------------------------------

DROP FUNCTION IF EXISTS MY_DEVIAZIONE;

DELIMITER $$
CREATE FUNCTION MY_DEVIAZIONE(valore_iniziale FLOAT, data_iniziale DATETIME,
								valore FLOAT, datazione DATETIME)
RETURNS FLOAT DETERMINISTIC
BEGIN
	DECLARE num FLOAT DEFAULT 0;
    DECLARE den FLOAT DEFAULT 0;
    DECLARE deviazione FLOAT DEFAULT 0;


	SET num = valore - valore_iniziale;
    SET den = DATEDIFF(datazione, data_iniziale);
    
    SET deviazione = (num/den)*(num/den);

	RETURN deviazione;

END $$
DELIMITER ;
#------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS MY_UMIDITA;

DELIMITER $$
CREATE FUNCTION MY_UMIDITA(temperatura FLOAT, umidita FLOAT)
RETURNS FLOAT DETERMINISTIC
BEGIN
	DECLARE fascia INT DEFAULT 0;

	IF temperatura < 20 THEN
		CASE
        WHEN umidita>=75 AND umidita<80  THEN
			SET fascia = 1;
        WHEN umidita>=80 AND umidita<85 THEN
			SET fascia = 2;
		WHEN umidita>=85 AND umidita<90 THEN
			SET fascia = 3;
		WHEN umidita>=90 AND umidita<=100 THEN
			SET fascia = 4;
		END CASE;
	ELSEIF temperatura >= 20 AND temperatura < 22 THEN
		CASE
        WHEN umidita>=70 AND umidita<75  THEN
			SET fascia = 1;
        WHEN umidita>=75 AND umidita<80 THEN
			SET fascia = 2;
		WHEN umidita>=80 AND umidita<85 THEN
			SET fascia = 3;
		WHEN umidita>=85 AND umidita<=100 THEN
			SET fascia = 4;
		END CASE;
	ELSEIF temperatura >= 22 AND temperatura < 24 THEN
		CASE
        WHEN umidita>=65 AND umidita<70  THEN
			SET fascia = 1;
        WHEN umidita>=70 AND umidita<75 THEN
			SET fascia = 2;
		WHEN umidita>=75 AND umidita<80 THEN
			SET fascia = 3;
		WHEN umidita>=80 AND umidita<=100 THEN
			SET fascia = 4;
		END CASE;
	ELSEIF temperatura >= 24 AND temperatura < 26 THEN
		CASE
        WHEN umidita>=40 AND umidita<45  THEN
			SET fascia = 1;
        WHEN umidita>=45 AND umidita<60 THEN
			SET fascia = 2;
		WHEN umidita>=60 AND umidita<75 THEN
			SET fascia = 3;
		WHEN umidita>=75 AND umidita<=100 THEN
			SET fascia = 4;
		END CASE;
	ELSEIF temperatura >=26 THEN
		CASE
        WHEN umidita>=35 AND umidita<40  THEN
			SET fascia = 1;
        WHEN umidita>=40 AND umidita<45 THEN
			SET fascia = 2;
		WHEN umidita>=45 AND umidita<50 THEN
			SET fascia = 3;
		WHEN umidita>=50 AND umidita<=100 THEN
			SET fascia = 4;
		END CASE;
    END IF ;

	RETURN fascia;

END $$
DELIMITER ;
#------------------------------------------------------------------------------------------














