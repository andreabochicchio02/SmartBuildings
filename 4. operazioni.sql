
#--------------------- 1. Elenco dei gruppi di lavoro ---------------------
DROP PROCEDURE IF EXISTS elenco_gruppi_lavoro;

DELIMITER $$
CREATE PROCEDURE elenco_gruppi_lavoro(IN _Datazione DATETIME)
	BEGIN
		WITH gruppo_lavoratori AS(
		SELECT C.Lavoratore AS Matricola, C.Mansione, 
				IF(C.IdSupervisore IS NULL, "è un supervisore", C.IdSupervisore) AS IdSupervisore
		FROM calendario C
        WHERE DATE_FORMAT(C.GiornoEdOrario, '%Y|%M|%d') = DATE_FORMAT(_Datazione, '%Y|%M|%d') 
			AND HOUR(_Datazione) - HOUR(C.GiornoEdOrario) < C.Durata
		)
        SELECT GL.Matricola, L.Cognome, L.Nome, GL.Mansione, GL.IdSupervisore
        FROM gruppo_lavoratori GL
			NATURAL JOIN
            lavoratore L;
	END $$
DELIMITER ;

#CALL elenco_gruppi_lavoro("2018-07-26 14:00");
#------------------------------------------------------------------------




#--------------------- 2. Sensori con deviazione standard più elevata ----
DROP PROCEDURE IF EXISTS crescita_sensori;

DELIMITER $$
CREATE PROCEDURE crescita_sensori()
	BEGIN
		WITH misurazioni_posizione AS(
			SELECT *
			FROM misurazione M
			WHERE M.Tipologia = "spostamento murario"
        ),
        dati AS(
        SELECT S.Id, M.DataRilevamento, M.Intensita,
				FIRST_VALUE (M.Intensita) OVER(
					PARTITION BY S.Id
                    ORDER BY M.DataRilevamento
					) AS riferimento,
				FIRST_VALUE (M.DataRilevamento) OVER(
					PARTITION BY S.Id
                    ORDER BY M.DataRilevamento
					) AS tempo,
				MAX(M.Intensita) OVER(
					PARTITION BY S.Id
					) AS MassimaMisurazione,
				S.Soglia
        FROM sensore S
			INNER JOIN
            misurazioni_posizione M ON S.ID = M.Sensore
		),
        somme AS(
        SELECT D.Id, D.MassimaMisurazione, D.Soglia, MY_DEVIAZIONE(D.riferimento, D.tempo, D.Intensita, D.DataRilevamento) AS valore
        FROM dati D
        ),
        deviazione AS(
        SELECT S.Id, S.MassimaMisurazione, S.Soglia, iFNULL(sqrt(SUM(S.Valore)/COUNT(*)), 0) AS sigma
        FROM somme S
        GROUP BY S.Id
        )
        SELECT D.Id, D.MassimaMisurazione, D.Soglia, D.sigma
        FROM deviazione D
        WHERE sigma > 0
        ORDER BY (sigma) DESC
        LIMIT 50;
        
	END $$
DELIMITER ;

#CALL crescita_sensori();
#--------------------------------------------------------------------------




#------------ 3. Elenco lavoratori che hanno svolto lavori sul vano --------
DROP PROCEDURE IF EXISTS lavori_sul_vano;

DELIMITER $$
CREATE PROCEDURE lavori_sul_vano(IN _Edificio CHAR(5), IN _NumVano INT)
	BEGIN
		WITH pavimen_vano AS(
			SELECT P.Piastrella AS CodiceLotto
            FROM pavimentazione P
			WHERE P.Vano = _NumVano
				AND P.Edificio = _Edificio
        ),
        materiali_vano AS(
			SELECT I.AltriMateriali AS CodiceLotto
            FROM impiego I
			WHERE I.Vano = _NumVano
				AND I.Edificio = _Edificio
        ),
        lavori_vano AS(
			SELECT DISTINCT O.Lavoro, O.StadioAvanzamento
			FROM occorrenza O 
			WHERE O.Materiale IN (
									SELECT P.CodiceLotto
									FROM pavimen_vano P
								)
					OR 
				   O.Materiale IN (
									SELECT MV.CodiceLotto
									FROM materiali_vano MV
								)
		),
        lavoratori_vano AS(
			SELECT M.Lavoratore, LV.Lavoro
            FROM manodopera M
				NATURAL JOIN
                lavori_vano LV
        )
			SELECT L.Matricola, L.Nome, L.Cognome, LV.Lavoro
            FROM lavoratori_vano LV
				INNER JOIN
                lavoratore L ON LV.Lavoratore = L.Matricola;
        
        
	END $$
DELIMITER ;

#CALL lavori_sul_vano("aaaa1", 1);
#---------------------------------------------------------------------------





#--------------------- 4. Calcolo del costo di un lavoro -----------------
DROP PROCEDURE IF EXISTS calcolo_costo_lavoro;

DELIMITER $$
CREATE PROCEDURE calcolo_costo_lavoro(IN  _StadioAvanzamento INT, IN _Lavoro VARCHAR(45))
	BEGIN
		DECLARE CostoLavoratori FLOAT DEFAULT 0;
        DECLARE CostoMateriali FLOAT DEFAULT 0;
        
		WITH my_lavoro AS(
			SELECT L.Nome, L.StadioAvanzamento, L.Inizio, L.Termine
			FROM lavoro L
			WHERE L.Nome = _Lavoro
				AND L.StadioAvanzamento = _StadioAvanzamento
		),
        my_manodopera AS(
        SELECT M.Lavoratore, L.Inizio, L.Termine, L.Nome
        FROM manodopera M
			INNER JOIN
            my_lavoro L ON (
							M.Lavoro = L.Nome
							AND M.StadioAvanzamento = M.StadioAvanzamento
							)
		),
        my_lavoratore AS(
		SELECT L.Matricola, L.PagaOraria, M.Inizio, M.Termine, M.Nome
        FROM Lavoratore L
			INNER JOIN
            my_manodopera M ON L.Matricola = M.Lavoratore
		)
        SELECT IFNULL(SUM(C.Durata * ML.PagaOraria), 0) INTO CostoLavoratori
        FROM Calendario C
			INNER JOIN
            my_lavoratore ML ON C.Lavoratore = ML.Matricola
		WHERE C.GiornoEdOrario 
			BETWEEN ML.Inizio AND ML.Termine
            AND C.Mansione = ML.Nome;
		
		
		WITH my_lavoro AS(
			SELECT L.Nome, L.StadioAvanzamento
			FROM lavoro L
			WHERE L.Nome = _Lavoro
				AND L.StadioAvanzamento = _StadioAvanzamento
		),
        my_materiale AS(
        SELECT O.Materiale, O.PercUtilizzo
        FROM my_lavoro ML
			INNER JOIN
            Occorrenza O ON (
					O.StadioAvanzamento = ML.StadioAvanzamento
                    AND O.Lavoro = ML.Nome
                    )
		)
        SELECT IFNULL(SUM(MM.Percutilizzo * M.Costo), 0) INTO CostoMateriali
        FROM my_materiale MM
			INNER JOIN
            materiale M ON MM.Materiale = M.CodiceLotto;
            
		UPDATE Lavoro
        SET  Costo = CostoMateriali + CostoLavoratori
        WHERE Nome = _Lavoro
			AND StadioAvanzamento = _StadioAvanzamento;

	END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS costo_lavoro;
DELIMITER $$
CREATE PROCEDURE costo_lavoro(IN  _StadioAvanzamento INT, IN _Lavoro VARCHAR(45))
	BEGIN
		SELECT L.Nome, L.Costo
        FROM Lavoro L
        WHERE L.Nome = _lavoro
			AND L.StadioAvanzamento = _StadioAvanzamento;

	END $$
DELIMITER ;


#CALL calcolo_costo_lavoro(32658, "realizzazione di pilastri");
#CALL costo_lavoro(32658, "realizzazione di pilastri");
#------------------------------------------------------------------------




#------------------ 5. Elenco dei materiali in esaurimento ---------------
DROP PROCEDURE IF EXISTS esaurimento_materiali;

DELIMITER $$
CREATE PROCEDURE esaurimento_materiali()
	BEGIN
		WITH elenco AS(
			SELECT m.CodiceLotto, M.Nome
			FROM Materiale M
        )
        SELECT DISTINCT E.Nome
        FROM elenco E
			INNER JOIN
            occorrenza O ON E.CodiceLotto = O.Materiale
		GROUP BY E.CodiceLotto
        HAVING SUM(PercUtilizzo)*100 > 80
			AND E.Nome NOT IN(
							SELECT E.Nome
							FROM elenco E
								INNER JOIN
								occorrenza O ON E.CodiceLotto = O.Materiale
							GROUP BY E.CodiceLotto
							HAVING SUM(PercUtilizzo)*100 < 80
						)
		ORDER BY SUM(PercUtilizzo)*100 DESC;
		

	END $$
DELIMITER ;

#CALL esaurimento_materiali();
#------------------------------------------------------------------------




#--------------------- 6. Numero vani in un piano ---------------------
DROP PROCEDURE IF EXISTS num_vani;

DELIMITER $$
CREATE PROCEDURE num_vani(IN _Edificio CHAR(5), IN _Piano INT)
	BEGIN
		SELECT NumeroVani
        FROM Pianta P
        WHERE P.Edificio = _Edificio
			AND P.Piano = _Piano;

	END $$
DELIMITER ;

#CALL num_vani("aaaa3", 5);
#------------------------------------------------------------------------



#--------------------- 7. Gravita evento calamitoso ------------------------
DROP PROCEDURE IF EXISTS gravita_sisma;
DELIMITER $$
CREATE PROCEDURE gravita_sisma(IN _genere VARCHAR(45), IN _data DATETIME)
	BEGIN
		DECLARE finito INT DEFAULT 0;
        DECLARE zona_colpita INT;
        DECLARE valore FLOAT DEFAULT 0;
        
				DECLARE cur_sisma CURSOR FOR
				WITH my_sensori AS(
				SELECT *
                FROM sensore S
					INNER JOIN
					misurazione M ON S.Id = M.Sensore
                WHERE (S.Tipo = "accelerometro"
					OR S.Tipo = "giroscopio")
                    AND M.DataRilevamento <= _data + INTERVAL 2 MINUTE
                    AND M.DataRilevamento >= _data - INTERVAL 2 MINUTE
                    AND M.Intensita > 0.80*S.Soglia
				),
                my_edifici AS(
                SELECT MS.Id, MS.Soglia, MS.Intensita, MS.Tipo, D.edificio
                FROM my_sensori MS
					INNER JOIN
                    demarcazione D ON MS.Mura = D.Mura
				),
                dati AS(
                SELECT E.AreaGeogCap, ME.Tipo, AVG(ME.Intensita) - ME.Soglia AS variazione
                FROM my_edifici ME
					INNER JOIN
                    edificio E ON ME.Edificio = E.Identificativo
				GROUP BY E.AreaGeogCap, ME.Tipo
                )
                SELECT DISTINCT D1.AreaGeogCap, (D1.Variazione+D2.Variazione)/2 AS valori_sisma
                FROM dati D1
					INNER JOIN
                    dati D2 ON (D1.AreaGeogCap = D2.AreaGeogCap
								AND D1.Tipo <> D2.Tipo);
                                
        DECLARE CONTINUE HANDLER
			FOR NOT FOUND SET finito = 1;
        
			OPEN cur_sisma;
			preleva : LOOP
            
				FETCH cur_sisma INTO zona_colpita, valore;
				
				IF finito = 1 THEN
					LEAVE preleva;
				END IF;
                
                CASE
				WHEN valore < 0  THEN
					INSERT INTO rilevazione
                    VALUE (1, zona_colpita, _genere, _data, "codice verde"); 
				WHEN valore >= 0 AND valore < 25 THEN
					INSERT INTO rilevazione
                    VALUE (1, zona_colpita, _genere, _data, "codice giallo"); 
				WHEN valore >= 25 AND valore < 70 THEN
					INSERT INTO rilevazione
                    VALUE (1, zona_colpita, _genere, _data, "codice arancione"); 
				WHEN valore >= 70 THEN
					INSERT INTO rilevazione
                    VALUE (1, zona_colpita, _genere, _data, "codice rosso"); 
				END CASE;
                
		END LOOP preleva;
        CLOSE cur_sisma;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS gravita_alluvione;
DELIMITER $$
CREATE PROCEDURE gravita_alluvione(IN _genere VARCHAR(45), IN _data DATETIME)
	BEGIN
		DECLARE finito INT DEFAULT 0;
        DECLARE zona_colpita INT;
        DECLARE valore FLOAT DEFAULT 0;
        
				DECLARE cur_alluvione CURSOR FOR
				WITH dati AS(
				SELECT S.Id, S.Soglia, M.Intensita, S.Tipo, S.Edificio
                FROM sensore S
					INNER JOIN
					misurazione M ON S.Id = M.Sensore
                WHERE (S.Tipo = "rilevatore acqua")
                    AND M.DataRilevamento <= _data + INTERVAL 5 HOUR
                    AND M.DataRilevamento >= _data - INTERVAL 1 HOUR
                    AND M.Intensita > 0.80*S.Soglia
				)
                SELECT E.AreaGeogCap, AVG(ME.Intensita) - ME.Soglia AS variazione
                FROM dati ME
					INNER JOIN
                    edificio E ON ME.Edificio = E.Identificativo
				GROUP BY E.AreaGeogCap, ME.Tipo;
		
        DECLARE CONTINUE HANDLER
			FOR NOT FOUND SET finito = 1;
        
			OPEN cur_alluvione;
			preleva : LOOP
            
				FETCH cur_alluvione INTO zona_colpita, valore;
				
				IF finito = 1 THEN
					LEAVE preleva;
				END IF;
                
                CASE
				WHEN valore < 0  THEN
					INSERT INTO rilevazione
                    VALUE (1, zona_colpita, _genere, _data, "codice verde"); 
				WHEN valore >= 0 AND valore < 1.5 THEN
					INSERT INTO rilevazione
                    VALUE (1, zona_colpita, _genere, _data, "codice giallo"); 
				WHEN valore >= 1.5 AND valore < 3 THEN
					INSERT INTO rilevazione
                    VALUE (1, zona_colpita, _genere, _data, "codice arancione"); 
				WHEN valore >= 3 THEN
					INSERT INTO rilevazione
                    VALUE (1, zona_colpita, _genere, _data, "codice rosso"); 
				END CASE;
                
		END LOOP preleva;
        CLOSE cur_alluvione;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS gravita_fuga;
DELIMITER $$
CREATE PROCEDURE gravita_fuga(IN _genere VARCHAR(45), IN _data DATETIME)
	BEGIN
		DECLARE finito INT DEFAULT 0;
        DECLARE zona_colpita INT;
        DECLARE valore FLOAT DEFAULT 0;
        DECLARE pericolo INT DEFAULT 0;
        
				DECLARE cur_fuga CURSOR FOR
				WITH my_sensori AS(
				SELECT *
                FROM sensore S
					INNER JOIN
					misurazione M ON S.Id = M.Sensore
                WHERE (S.Tipo = "accelerometro"
					OR S.Tipo = "giroscopio"
                    OR S.Tipo = "rilevatore gas")
                    AND M.DataRilevamento <= _data + INTERVAL 1 HOUR
                    AND M.DataRilevamento >= _data - INTERVAL 30 MINUTE
                    AND M.Intensita > 0.80*S.Soglia
				),
                my_edifici AS(
                SELECT MS.Id, MS.Soglia, IFNULL(MS.Intensita, 0) AS Intensita, MS.Tipo, IFNULL(D.edificio, MS.Edificio) AS Edificio
                FROM my_sensori MS
					LEFT OUTER JOIN
                    demarcazione D ON MS.Mura = D.Mura
				),
                dati AS(
                SELECT E.AreaGeogCap, ME.Tipo, AVG(ME.Intensita) - ME.Soglia AS variazione
                FROM my_edifici ME
					INNER JOIN
                    edificio E ON ME.Edificio = E.Identificativo
				GROUP BY E.AreaGeogCap, ME.Tipo
                )
                SELECT DISTINCT D1.AreaGeogCap, (D1.Variazione+D2.Variazione+D3.Variazione)/3 AS valori_sisma
                FROM dati D1
					INNER JOIN
                    dati D2 
                    INNER JOIN
                    dati D3 
                    WHERE D1.AreaGeogCap = D2.AreaGeogCap
							AND D3.AreaGeogCap = D2.AreaGeogCap
							AND D1.Tipo <> D2.Tipo
                            AND D2.Tipo <> D3.Tipo
                            AND D1.Tipo <> D3.Tipo;
		
        DECLARE CONTINUE HANDLER
			FOR NOT FOUND SET finito = 1;
            
            SELECT COUNT(*) INTO pericolo
            FROM misurazione M
            WHERE M.DataRilevamento = _data
				AND M.Tipologia = "livello gas nell'aria"
                AND M.Alert = 1
                ;
            IF pericolo <> 0 THEN
        
			OPEN cur_fuga;
			preleva : LOOP
            
				FETCH cur_fuga INTO zona_colpita, valore;
				
				IF finito = 1 THEN
					LEAVE preleva;
				END IF;
                
                
                CASE
				WHEN valore < 50  THEN
					INSERT INTO rilevazione
                    VALUE (1, zona_colpita, _genere, _data, "codice verde"); 
				WHEN valore >= 50 AND valore < 75 THEN
					INSERT INTO rilevazione
                    VALUE (1, zona_colpita, _genere, _data, "codice giallo"); 
				WHEN valore >= 75 AND valore < 100 THEN
					INSERT INTO rilevazione
                    VALUE (1, zona_colpita, _genere, _data, "codice arancione"); 
				WHEN valore >= 100 THEN
					INSERT INTO rilevazione
                    VALUE (1, zona_colpita, _genere, _data, "codice rosso"); 
				END CASE;
                
		END LOOP preleva;
        CLOSE cur_fuga;
		END IF;
        
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS caso_generale;
DELIMITER $$
CREATE PROCEDURE caso_generale(IN _genere VARCHAR(45), IN _data DATETIME)
	BEGIN
		DECLARE finito INT DEFAULT 0;
        DECLARE zona_colpita INT;
        DECLARE valore FLOAT DEFAULT 0;
        
				DECLARE cur_generale CURSOR FOR
				WITH my_sensori AS(
				SELECT *
                FROM sensore S
					INNER JOIN
					misurazione M ON S.Id = M.Sensore
                WHERE (S.Tipo = "accelerometro"
					OR S.Tipo = "giroscopio")
                    AND M.DataRilevamento = _data
                    AND M.Intensita > 0.80*S.Soglia
				),
                my_edifici AS(
                SELECT MS.Id, MS.Soglia, MS.Intensita, MS.Tipo, D.edificio
                FROM my_sensori MS
					INNER JOIN
                    demarcazione D ON MS.Mura = D.Mura
				),
                dati AS(
                SELECT E.AreaGeogCap, ME.Tipo, AVG(ME.Intensita) - ME.Soglia AS variazione
                FROM my_edifici ME
					INNER JOIN
                    edificio E ON ME.Edificio = E.Identificativo
				GROUP BY E.AreaGeogCap, ME.Tipo
                )
                SELECT DISTINCT D1.AreaGeogCap, (D1.Variazione+D2.Variazione)/2 AS valori_sisma
                FROM dati D1
					INNER JOIN
                    dati D2 ON (D1.AreaGeogCap = D2.AreaGeogCap
								AND D1.Tipo <> D2.Tipo);
		
        DECLARE CONTINUE HANDLER
			FOR NOT FOUND SET finito = 1;
        
			OPEN cur_generale;
			preleva : LOOP
            
				FETCH cur_generale INTO zona_colpita, valore;
				
				IF finito = 1 THEN
					LEAVE preleva;
				END IF;
                
                CASE
				WHEN valore < 25  THEN
					INSERT INTO rilevazione
                    VALUE (1, zona_colpita, _genere, _data, "codice verde"); 
				WHEN valore >= 25 THEN
					INSERT INTO rilevazione
                    VALUE (1, zona_colpita, _genere, _data, "codice giallo"); 
				END CASE;
                
		END LOOP preleva;
        CLOSE cur_generale;

END $$
DELIMITER ;


DROP PROCEDURE IF EXISTS gravita;
DELIMITER $$
CREATE PROCEDURE gravita(IN _genere VARCHAR(45), IN _data DATETIME)
BEGIN
	IF _genere = "sisma" THEN
		CALL gravita_sisma(_genere, _data);
	ELSEIF _genere = "alluvione" OR _genere = "esondazione" THEN
		CALL gravita_alluvione(_genere, _data);
	ELSEIF _genere= "fuga di gas" THEN
		CALL gravita_fuga(_genere, _data);
	ELSE
		CALL caso_generale(_genere, _data);
    END IF;
    
END $$
DELIMITER ;

#CALL gravita("alluvione", "2019-03-17 10:10");
#CALL gravita("alluvione", "2020-05-04 00:10");
#CALL gravita("fuga di gas", "2021-06-10 10:05");
#CALL gravita("sisma", "2020-11-21 11:31");
#CALL gravita("esplosione", "2019-07-31 09:24");


# set @@foreign_key_checks = 0; TRUNCATE TABLE rilevazione; set @@foreign_key_checks = 1;

/*
SELECT *
FROM rilevazione;*/
#------------------------------------------------------------------------




#--------------------- 8. Stato di un edificio ---------------------
DROP PROCEDURE IF EXISTS stato_edificio;

DELIMITER $$
CREATE PROCEDURE stato_edificio(IN _edificio CHAR(5))
	BEGIN
        DECLARE parametri_climatici VARCHAR(45);
        
        DECLARE media_termometri FLOAT DEFAULT 0;
        DECLARE stato_termometri INT DEFAULT 0;
        
        DECLARE media_igrometri FLOAT DEFAULT 0;
        DECLARE stato_igrometri INT DEFAULT 0;
        
        
        DECLARE parametri_strutturali VARCHAR(45);
        
        DECLARE media_giroscopi FLOAT DEFAULT 0;
        DECLARE stato_giroscopi INT DEFAULT 0;
        
        DECLARE media_accelerometri FLOAT DEFAULT 0;
        DECLARE stato_accelerometri INT DEFAULT 0;
        
        DECLARE media_posizione FLOAT DEFAULT 0;
        DECLARE stato_posizione INT DEFAULT 0;
        
       
        
        
		#termometri
        SELECT AVG(M.Intensita) INTO media_termometri
        FROM Sensore S
			INNER JOIN
            misurazione M ON M.Sensore = S.Id
        WHERE S.EdificioVano = _edificio
			AND S.Tipo = "termometro";
            
		IF media_termometri IS NULL THEN
			SET media_termometri=0;
		END IF;

            
		CASE
        WHEN media_termometri >= 18 AND media_termometri < 22 THEN
			SET stato_termometri = 1;
        WHEN media_termometri >= 16 AND media_termometri < 18 OR
			media_termometri >= 22 AND media_termometri < 24 THEN
			SET stato_termometri = 2;
		WHEN media_termometri >= 14 AND media_termometri < 16 OR
			media_termometri >= 24 AND media_termometri < 26 THEN
			SET stato_termometri = 3;
		WHEN media_termometri <14 OR media_termometri >=26 THEN
			SET stato_termometri = 4;
		END CASE;
	
    
		#igrometri
		SELECT AVG(M.Intensita) INTO media_igrometri
        FROM Sensore S
			INNER JOIN
            misurazione M ON M.Sensore = S.Id
        WHERE S.EdificioVano = _edificio
			AND S.Tipo = "igrometro";
            
		IF media_igrometri IS NULL THEN
			SET media_igrometri=0;
		END IF;
        
            
		CASE
        WHEN media_igrometri >= 50 AND media_igrometri < 60 THEN
			SET stato_igrometri = 1;
        WHEN media_igrometri >= 47 AND media_igrometri < 50 OR
			media_igrometri >= 60 AND media_igrometri < 65 THEN
			SET stato_igrometri = 2;
		WHEN media_igrometri >= 44 AND media_igrometri < 47 OR
			media_igrometri >= 65 AND media_igrometri < 70 THEN
			SET stato_igrometri = 3;
		WHEN media_igrometri < 44 OR media_igrometri >= 70 THEN
			SET stato_igrometri = 4;
		END CASE;
        
        CASE
        WHEN (stato_termometri+stato_igrometri)/2 < 1.6 THEN
			SET parametri_climatici = "ottimo";
        WHEN (stato_termometri+stato_igrometri)/2 >= 1.6 AND
			(stato_termometri+stato_igrometri)/2 < 2.5 THEN
			SET parametri_climatici = "buono";
		WHEN (stato_termometri+stato_igrometri)/2 >= 2.5 AND
			(stato_termometri+stato_igrometri)/2 < 3.5 THEN
			SET parametri_climatici = "discreto";
		WHEN (stato_termometri+stato_igrometri)/2 >= 3.5 THEN
			SET parametri_climatici = "pessimo";
		END CASE;
        
        
        
        #giroscopi
        WITH my_giroscopi AS(
        SELECT S.Id, S.Soglia
        FROM Sensore S
			INNER JOIN
            demarcazione P ON S.Mura = P.Mura
        WHERE P.Edificio = _edificio
			AND S.Tipo = "giroscopio"
		),
        my_misurazioni AS(
			SELECT AVG(M.Intensita) AS media, MG.Soglia
			FROM my_giroscopi MG
				INNER JOIN
				misurazione M ON MG.Id = M.Sensore
            WHERE CURRENT_DATE < M.DataRilevamento + INTERVAL 3 MONTH
			GROUP BY M.Tipologia
		)
        SELECT AVG(media) - soglia INTO media_giroscopi
        FROM my_misurazioni;
        
        IF media_giroscopi IS NULL THEN
			SET media_giroscopi=0;
		END IF;
        
		CASE
        WHEN media_giroscopi < 0  THEN
			SET stato_giroscopi = 1;
        WHEN media_giroscopi >= 0 AND media_giroscopi < 25 THEN
			SET stato_giroscopi = 2;
		WHEN media_giroscopi >= 25 AND media_giroscopi < 70 THEN
			SET stato_giroscopi = 3;
		WHEN media_giroscopi >= 70 THEN
			SET stato_giroscopi = 4;
		END CASE;
        
        #accelerometri
        WITH my_accelerometri AS(
        SELECT S.Id, S.Soglia
        FROM Sensore S
			INNER JOIN
            demarcazione P ON S.Mura = P.Mura
        WHERE P.Edificio = _edificio
			AND S.Tipo = "accelerometro"
		),
        my_misurazioni AS(
			SELECT AVG(M.Intensita) AS media, AVG(MA.Soglia) AS soglia
			FROM my_accelerometri MA
				INNER JOIN
				misurazione M ON MA.Id = M.Sensore
            WHERE CURRENT_DATE < M.DataRilevamento + INTERVAL 3 MONTH
			GROUP BY M.Tipologia
		)
        SELECT AVG(media) - soglia INTO media_accelerometri
        FROM my_misurazioni;
        
        IF media_accelerometri IS NULL THEN
			SET media_accelerometri=0;
		END IF;
	
        
		CASE
        WHEN media_accelerometri < 0  THEN
			SET stato_accelerometri = 1;
        WHEN media_accelerometri >= 0 AND media_accelerometri < 25 THEN
			SET stato_accelerometri = 2;
		WHEN media_accelerometri >= 25 AND media_accelerometri < 70 THEN
			SET stato_accelerometri = 3;
		WHEN media_accelerometri >= 70 THEN
			SET stato_accelerometri = 4;
		END CASE;
        
        
        
        #posizione
        WITH my_posizione AS(
        SELECT S.Id, S.Soglia
        FROM Sensore S
			INNER JOIN
            demarcazione P ON S.Mura = P.Mura
        WHERE P.Edificio = _edificio
			AND S.Tipo = "posizione"
		)
		SELECT AVG(M.Intensita) - MP.Soglia INTO media_posizione
		FROM my_posizione MP
			INNER JOIN
			misurazione M ON MP.Id = M.Sensore
		WHERE CURRENT_DATE < M.DataRilevamento + INTERVAL 3 MONTH;

		IF media_posizione IS NULL THEN
			SET media_posizione=0;
		END IF;
        
		CASE
        WHEN media_posizione < 0  THEN
			SET stato_posizione = 1;
        WHEN media_posizione >= 0 AND media_posizione < 2 THEN
			SET stato_posizione = 2;
		WHEN media_posizione >= 2 AND media_posizione < 4 THEN
			SET stato_posizione = 3;
		WHEN media_posizione >= 4 THEN
			SET stato_posizione = 4;
		END CASE;
	
        
        CASE
        WHEN ((0.7 * stato_accelerometri) + (0.7 * stato_giroscopi) + (1.1 * stato_posizione))/3 < 0.9 THEN
			SET parametri_strutturali = "ottimo";
        WHEN ((0.7 * stato_accelerometri) + (0.7 * stato_giroscopi) + (1.1 *stato_posizione))/3 >= 0.9 AND
			((0.7 * stato_accelerometri) + (0.7 * stato_giroscopi) + (1.1 *stato_posizione))/3  < 1.3 THEN
			SET parametri_strutturali = "buono";
		WHEN ((0.7 * stato_accelerometri) + (0.7 * stato_giroscopi) + (1.1 *stato_posizione))/3 >= 1.3 AND
			((0.7 * stato_accelerometri) + (0.7 * stato_giroscopi) + (1.1 *stato_posizione))/3  < 1.6 THEN
			SET parametri_strutturali = "discreto";
		WHEN ((0.7 * stato_accelerometri) + (0.7 * stato_giroscopi) + (1.1 *stato_posizione))/3 >= 1.6 THEN
			SET parametri_strutturali = "pessimo";
		END CASE;
        
        INSERT INTO stato
        VALUE
			(CURRENT_TIME, parametri_strutturali, parametri_climatici, _edificio);
	
	END $$
DELIMITER ;

#CALL stato_edificio("aaaa1");
#CALL stato_edificio("dddd3");
#CALL stato_edificio("cccc7");

/*
SELECT *
FROM stato S
WHERE S.EdificioIdentificativo = "aaaa1"
ORDER BY (S.Data) DESC
LIMIT 1;
*/
#------------------------------------------------------------------------