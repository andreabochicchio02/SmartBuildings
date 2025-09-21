
#--------------------- Stima Danni ---------------------
DROP PROCEDURE IF EXISTS stima_danni;

DELIMITER $$
CREATE PROCEDURE stima_danni(IN _edificio CHAR(5))
	BEGIN
		DECLARE stato VARCHAR(45);
        DECLARE zona INT;
        DECLARE coef_rischio FLOAT DEFAULT 5;
        DECLARE danno INT DEFAULT 0;
        DECLARE arredo FLOAT DEFAULT 0;
        DECLARE infissi FLOAT DEFAULT 0;
        DECLARE muratura FLOAT DEFAULT 0;
        
        
        IF stato IS NULL THEN
			CALL stato_edificio(_edificio);
		END IF;
        
        
        SELECT ParametriStrutturali INTO stato
        FROM stato S
		WHERE S.EdificioIdentificativo = _edificio
        ORDER BY(S.Data) DESC
        LIMIT 1;
        
        
        
        #----------------------------------------------
        
        SELECT CoefRischioSismico INTO coef_rischio
        FROM areageografica A
			INNER JOIN
            edificio E ON E.AreaGeogCap = A.Cap
		WHERE E.Identificativo = _edificio
        ORDER BY(NumRegistrazione) DESC
        LIMIT 1;
        
        
        CASE
        WHEN coef_rischio < 0.05 THEN
			SET zona = 4;
        WHEN coef_rischio >= 0.05 AND coef_rischio < 0.15 THEN
			SET zona = 3;
		WHEN coef_rischio >= 0.15 AND coef_rischio < 0.25 THEN
			SET zona = 2;
		WHEN coef_rischio >= 0.25 THEN
			SET zona = 1;
		END CASE;
        
        #--------------------------------------------
        
        CASE
        WHEN stato = "ottimo" AND zona = 4 THEN
			SET danno = 0;
		WHEN stato = "buono" AND zona = 4
			OR stato = "ottimo" AND zona = 3	THEN
			SET danno = 1;
		WHEN stato = "discreto" AND zona = 4
			OR stato = "buono" AND zona = 3
			OR stato = "ottimo" AND zona = 2	THEN
			SET danno = 2;
		WHEN stato = "pessimo" AND zona = 4
			OR stato = "discreto" AND zona = 3
            OR stato = "buono" AND zona = 2
			OR stato = "ottimo" AND zona = 1	THEN
			SET danno = 3;
		WHEN stato = "pessimo" AND zona = 3
			OR stato = "discreto" AND zona = 2
			OR stato = "buono" AND zona = 1	THEN
			SET danno = 4;
		WHEN stato = "pessimo" AND zona = 2
			OR stato = "discreto" AND zona = 1	THEN
			SET danno = 5;
		WHEN stato = "pessimo" AND zona = 1 THEN
			SET danno = 6;
		END CASE;
        
        
        #--------------------------------------------
        
        CASE
        WHEN danno = 0 THEN
			SET arredo = 0.05; SET infissi = 0.02; SET muratura = 0.01;
		WHEN danno = 1 THEN
			SET arredo = 0.15; SET infissi = 0.10; SET muratura = 0.05;
		WHEN danno = 2 THEN
			SET arredo = 0.30; SET infissi = 0.20; SET muratura = 0.10;
		WHEN danno = 3 THEN
			SET arredo = 0.60; SET infissi = 0.40; SET muratura = 0.35;
		WHEN danno = 4 THEN
			SET arredo = 1.00; SET infissi = 0.60; SET muratura = 0.50;
		WHEN danno = 5 THEN
			SET arredo = 1.00; SET infissi = 1.00; SET muratura = 0.70;
		WHEN danno = 6 THEN
			SET arredo = 1.00; SET infissi = 1.00; SET muratura = 1.00;
		END CASE;
        
        
        INSERT INTO danni
        VALUE
			(CURRENT_TIME, muratura, infissi, arredo, _edificio);
        
        SELECT *
        FROM danni D
        WHERE D.Edificio = _edificio
        ORDER BY (D.Data) DESC
        LIMIT 1;

	END $$
DELIMITER ;

#CALL stima_danni("cccc7");
#CALL stima_danni("dddd3");




#--------------------- Consigli di intervento ---------------------
DROP PROCEDURE IF EXISTS consigli_intervento;

DROP PROCEDURE IF EXISTS consigli_intervento_muratura;
DELIMITER $$
CREATE PROCEDURE consigli_intervento_muratura(IN _edificio CHAR(5))
	BEGIN
		DECLARE lavoro VARCHAR(100) DEFAULT "";
        DECLARE priorita INT DEFAULT 0;
		DECLARE soglia VARCHAR(20) DEFAULT "";
        DECLARE limite VARCHAR(20) DEFAULT "";
        DECLARE incidenza FLOAT DEFAULT 0;
        DECLARE spesa INT DEFAULT 0;
        DECLARE stanza VARCHAR(25) DEFAULT "";
        DECLARE gia_presente INT DEFAULT 0;
        
        DECLARE finito INT DEFAULT 0;
        DECLARE media_valore FLOAT DEFAULT 0;
        DECLARE mura_crepa CHAR(6) DEFAULT "";
        
        DECLARE totale_misurazioni INT DEFAULT 0;
        DECLARE totale_alert INT DEFAULT 0;
    
    
		DECLARE crepe CURSOR FOR
			SELECT P.mura, AVG(M.Intensita) AS media_valore
			FROM Sensore S
				INNER JOIN
				demarcazione P ON S.Mura = P.Mura
				INNER JOIN
				misurazione M ON S.Id = M.Sensore
			WHERE P.Edificio = _edificio
				AND S.Tipo = "posizione"
				AND CURRENT_DATE < M.DataRilevamento + INTERVAL 3 MONTH
			GROUP BY P.Mura;
            
            
		
        DECLARE CONTINUE HANDLER 
        FOR NOT FOUND
        SET finito = 1;
        
        SELECT COUNT(*) INTO totale_misurazioni
		FROM Sensore S
			INNER JOIN
			demarcazione P ON S.Mura = P.Mura
			INNER JOIN
			misurazione M ON S.Id = M.Sensore
		WHERE P.Edificio = _edificio
			AND S.Tipo = "posizione"
			AND CURRENT_DATE < M.DataRilevamento + INTERVAL 3 MONTH;
		
		SELECT COUNT(*) INTO totale_alert
		FROM Sensore S
			INNER JOIN
			demarcazione P ON S.Mura = P.Mura
			INNER JOIN
			misurazione M ON S.Id = M.Sensore
		WHERE P.Edificio = _edificio
			AND S.Tipo = "posizione"
			AND CURRENT_DATE < M.DataRilevamento + INTERVAL 3 MONTH
            AND M.Alert =  true;
	
		IF(totale_misurazioni * 0.8 < totale_alert) THEN
			INSERT INTO consigliintervento
			VALUE
					("ristrutturazione", 4, "edificio", "3 mesi", "sisma", "2.5 pti", 0.8, 10000, _edificio);
		ELSE
        
        OPEN crepe;
        
        preleva: LOOP
			FETCH crepe INTO mura_crepa, media_valore;
			IF finito = 1 THEN
				LEAVE preleva;
			END IF;
            
            SELECT D.Vano INTO stanza
            FROM demarcazione D
				INNER JOIN
                Vano V ON (
						D.Vano = V.NumeroVano
                        AND D.Edificio = V.Edificio
                        )
            WHERE D.Mura = mura_crepa;
            
            IF media_valore <=2 THEN
				ITERATE preleva;
			END IF;
            
            CASE
			WHEN media_valore > 2 AND media_valore <= 5 THEN
				SET lavoro = CONCAT("sigillante crepe", " del vano ", stanza); 
                SET priorita = 1; SET soglia = "5 pti"; 
                SET limite = "10 anni"; SET incidenza = 0.4; SET spesa = 100;
			WHEN media_valore > 5 AND media_valore <= 10 THEN
				SET lavoro = CONCAT("stucco riempitivo", " del vano ", stanza); 
                SET priorita = 2; SET soglia = "4 pti"; 
                SET limite = "3 anni"; SET incidenza = 0.5; SET spesa = 500;
			WHEN media_valore > 10 THEN
				SET lavoro = CONCAT("consolidamento mura", " del vano ", stanza);
                SET priorita = 3; SET soglia = "3 pti"; 
                SET limite = "6 mesi"; SET incidenza = 0.65; SET spesa = 3000;
			END CASE;
            
            SELECT COUNT(*) INTO gia_presente
            FROM consigliintervento C
            WHERE C.Lavoro = lavoro;
            
            IF(gia_presente = 0) THEN
				INSERT INTO consigliintervento
				VALUE
					(lavoro, priorita, mura_crepa, limite, "sisma", soglia, incidenza, spesa, _edificio);
            END IF;
            

        END LOOP preleva;
        CLOSE crepe;
		
        END IF;
        
	END $$
DELIMITER ;


DROP PROCEDURE IF EXISTS consigli_intervento_umidita;
DELIMITER $$
CREATE PROCEDURE consigli_intervento_umidita(IN _edificio CHAR(5))
BEGIN
	DECLARE lavoro VARCHAR(100) DEFAULT "";
	DECLARE priorita INT DEFAULT 0;
	DECLARE soglia VARCHAR(20) DEFAULT "";
	DECLARE limite VARCHAR(20) DEFAULT "";
	DECLARE incidenza FLOAT DEFAULT 0;
	DECLARE spesa INT DEFAULT 0;
	DECLARE gia_presente INT DEFAULT 0;
    
	DECLARE vano_umidita INT DEFAULT 0;
    DECLARE fascia INT DEFAULT 0;
	DECLARE finito INT DEFAULT 0;
	
    DECLARE umidita CURSOR FOR
		WITH igrometro AS(
		SELECT S.vano, AVG(M.Intensita) AS media_umido
        FROM Sensore S
			INNER JOIN
            misurazione M ON S.Id = M.Sensore
        WHERE S.EdificioVano = _edificio
			AND S.Tipo = "igrometro"
		GROUP BY S.Vano
		),
        termometro AS(
		SELECT S.vano, AVG(M.Intensita) AS media_temp
        FROM Sensore S
			INNER JOIN
            misurazione M ON S.Id = M.Sensore
        WHERE S.EdificioVano = _edificio
			AND S.Tipo = "termometro"
		GROUP BY S.Vano
		)
        SELECT vano, MY_UMIDITA(T.media_temp, I.Media_umido) AS Fascia
        FROM igrometro I
			NATURAL JOIN
            termometro T ;
            

		DECLARE CONTINUE HANDLER 
        FOR NOT FOUND
        SET finito = 1;
            
		OPEN umidita;
        
        preleva: LOOP
			FETCH umidita INTO vano_umidita, fascia;
			IF finito = 1 THEN
				LEAVE preleva;
			END IF;
            
            IF fascia = 0 THEN
				ITERATE preleva;
			END IF;
            
            CASE
			WHEN fascia = 1 THEN
				SET lavoro = "deumidificatore"; 
                SET priorita = 1; SET soglia = "95%"; 
                SET limite = "1 anno"; SET incidenza = 0.6; SET spesa = 200;
			WHEN fascia = 2 THEN
				SET lavoro = "intonaco e tinteggiatura" ;
                SET priorita = 2; SET soglia = "90 %"; 
                SET limite = "5 mesi"; SET incidenza = 0.65; SET spesa = 400;
			WHEN fascia = 3 THEN
				SET lavoro = "vespaio";
                SET priorita = 3; SET soglia = "85%"; 
                SET limite = "1 mese"; SET incidenza = 0.70; SET spesa = 1000;
			WHEN fascia = 4 THEN
				SET lavoro = "cappotto";
                SET priorita = 4; SET soglia = "80%"; 
                SET limite = "2 settimane"; SET incidenza = 0.80; SET spesa = 2000;
			END CASE;
            
            SELECT COUNT(*) INTO gia_presente
            FROM consigliintervento C
            WHERE C.Lavoro = lavoro;
            
            IF(gia_presente = 0) THEN
				INSERT INTO consigliintervento
				VALUE
					(lavoro, priorita, vano_umidita, limite, "umidita esterna", soglia, incidenza, spesa, _edificio);
            END IF;

        END LOOP preleva;
        CLOSE umidita;

END $$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE consigli_intervento(IN _edificio CHAR(5))
BEGIN
	CALL consigli_intervento_umidita(_edificio);
    CALL consigli_intervento_muratura(_edificio);
END $$
DELIMITER ;


#CALL consigli_intervento("aaaa9");
#CALL consigli_intervento("bbbb1");

# set @@foreign_key_checks = 0; TRUNCATE TABLE consigliintervento; set @@foreign_key_checks = 1;

/*
SELECT *
FROM consigliintervento;
*/