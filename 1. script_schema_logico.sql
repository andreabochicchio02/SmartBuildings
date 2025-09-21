SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

CREATE SCHEMA IF NOT EXISTS `SmartBuildings` DEFAULT CHARACTER SET utf8 ;
USE `SmartBuildings` ;

-- -----------------------------------------------------
-- Table `AreaGeografica`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `AreaGeografica` ;

CREATE TABLE IF NOT EXISTS `AreaGeografica` (
  `NumRegistrazione` INT NOT NULL,
		CHECK(NumRegistrazione > 0),
  `Cap` INT NOT NULL,
		CHECK(Cap > 0),
  `CoefRischioSismico` FLOAT NOT NULL,
		CHECK(CoefRischioSismico > 0),
  `CoefRischioIdreogeologico` FLOAT NOT NULL,
		CHECK(CoefRischioIdreogeologico > 0),
  `DataVariazione` DATETIME NOT NULL,
  PRIMARY KEY (`NumRegistrazione`, `Cap`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Edificio`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Edificio` ;

CREATE TABLE IF NOT EXISTS `Edificio` (
  `Identificativo` CHAR(5) NOT NULL,
  `Comune` VARCHAR(45) NOT NULL,
  `Foglio` INT NOT NULL,
		CHECK(Foglio > 0),
  `Particella` INT NOT NULL,
		CHECK(Particella > 0),
  `Sub` INT NOT NULL,
		CHECK(Sub > 0),
  `Condizione` VARCHAR(45) NOT NULL,
		CHECK(Condizione = 'esistente' OR Condizione = 'da realizzare'),
  `Tipologia` VARCHAR(45) NOT NULL,
  `AreaGeogNumReg` INT NOT NULL,
  `AreaGeogCap` INT NOT NULL,
  PRIMARY KEY (`Identificativo`),
  INDEX `fk_Edificio_AreaGeografica1_idx` (`AreaGeogNumReg` ASC, `AreaGeogCap` ASC) VISIBLE,
  CONSTRAINT `fk_Edificio_AreaGeografica1`
    FOREIGN KEY (`AreaGeogNumReg` , `AreaGeogCap`)
    REFERENCES `AreaGeografica` (`NumRegistrazione` , `Cap`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Pianta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Pianta` ;

CREATE TABLE IF NOT EXISTS `Pianta` (
  `Codice` INT NOT NULL,
  `DimensionePerimetro` INT NOT NULL,
		CHECK(DimensionePerimetro > 0),
  `TipoPerimetro` VARCHAR(45) NOT NULL,
  `Piano` INT NOT NULL,
  `NumeroVani` INT NOT NULL,
  `Edificio` CHAR(5) NOT NULL,
  PRIMARY KEY (`Codice`),
  INDEX `fk_pianta_edificio_idx` (`Edificio` ASC) VISIBLE,
  CONSTRAINT `fk_pianta_edificio`
    FOREIGN KEY (`Edificio`)
    REFERENCES `Edificio` (`Identificativo`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Vano`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Vano` ;

CREATE TABLE IF NOT EXISTS `Vano` (
  `NumeroVano` INT NOT NULL,
		CHECK(NumeroVano > 0),
  `Piano` INT NOT NULL,
  `Larghezza` INT NOT NULL,
		CHECK(Larghezza > 0),
  `Lunghezza` INT NOT NULL,
		CHECK(Lunghezza > 0),
  `MassimaAltezza` INT NOT NULL,
		CHECK(MassimaAltezza > 0),
  `Edificio` CHAR(5) NOT NULL,
  PRIMARY KEY (`NumeroVano`, `Edificio`),
  INDEX `fk_vano_edificio1_idx` (`Edificio` ASC) VISIBLE,
  CONSTRAINT `fk_vano_edificio1`
    FOREIGN KEY (`Edificio`)
    REFERENCES `Edificio` (`Identificativo`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Mura`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Mura` ;

CREATE TABLE IF NOT EXISTS `Mura` (
  `Codice` CHAR(6) NOT NULL,
  `SSI1` INT NULL,
		CHECK(SSI1 > 0),
  `SSI2` INT NULL,
		CHECK(SSI2 > 0),
  `SSI3` INT NULL,
		CHECK(SSI3 > 0),
  `SSI4` INT NULL,
		CHECK(SSI4 > 0),
  PRIMARY KEY (`Codice`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Sensore`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Sensore` ;

CREATE TABLE IF NOT EXISTS `Sensore` (
  `ID` CHAR(6) NOT NULL,
  `Tipo` VARCHAR(45) NOT NULL,
  `Soglia` INT NOT NULL,
  `Edificio` CHAR(5) NULL,
  `Vano` INT NULL,
  `EdificioVano` CHAR(5) NULL,
  `Mura` CHAR(6) NULL,
  PRIMARY KEY (`ID`),
  INDEX `fk_sensore_edificio1_idx` (`Edificio` ASC) VISIBLE,
  INDEX `fk_sensore_vano1_idx` (`Vano` ASC, `EdificioVano` ASC) VISIBLE,
  INDEX `fk_sensore_mura1_idx` (`Mura` ASC) VISIBLE,
  CONSTRAINT `fk_sensore_edificio1`
    FOREIGN KEY (`Edificio`)
    REFERENCES `Edificio` (`Identificativo`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_sensore_vano1`
    FOREIGN KEY (`Vano` , `EdificioVano`)
    REFERENCES `Vano` (`NumeroVano` , `Edificio`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_sensore_mura1`
    FOREIGN KEY (`Mura`)
    REFERENCES `Mura` (`Codice`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Misurazione`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Misurazione` ;

CREATE TABLE IF NOT EXISTS `Misurazione` (
  `DataRilevamento` DATETIME NOT NULL,
  `Tipologia` VARCHAR(45) NOT NULL,
  `Intensita` FLOAT NOT NULL,
  `UnitaDiMisura` VARCHAR(45) NOT NULL,
  `Alert` TINYINT NOT NULL,
  `Sensore` CHAR(6) NOT NULL,
  PRIMARY KEY (`DataRilevamento`, `Tipologia`, `Sensore`),
  INDEX `fk_misurazione_sensore1_idx` (`Sensore` ASC) VISIBLE,
  CONSTRAINT `fk_misurazione_sensore1`
    FOREIGN KEY (`Sensore`)
    REFERENCES `Sensore` (`ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Funzionalita`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Funzionalita` ;

CREATE TABLE IF NOT EXISTS `Funzionalita` (
  `Nome` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`Nome`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Tipologia`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Tipologia` ;

CREATE TABLE IF NOT EXISTS `Tipologia` (
  `Funzionalita` VARCHAR(45) NOT NULL,
  `Vano` INT NOT NULL,
  `Edificio` CHAR(5) NOT NULL,
  PRIMARY KEY (`Funzionalita`, `Vano`, `Edificio`),
  INDEX `fk_funzionalita_has_vano_vano1_idx` (`Vano` ASC, `Edificio` ASC) VISIBLE,
  INDEX `fk_funzionalita_has_vano_funzionalita1_idx` (`Funzionalita` ASC) VISIBLE,
  CONSTRAINT `fk_funzionalita_has_vano_funzionalita1`
    FOREIGN KEY (`Funzionalita`)
    REFERENCES `Funzionalita` (`Nome`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_funzionalita_has_vano_vano1`
    FOREIGN KEY (`Vano` , `Edificio`)
    REFERENCES `Vano` (`NumeroVano` , `Edificio`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Finestra`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Finestra` ;

CREATE TABLE IF NOT EXISTS `Finestra` (
  `Indice` INT NOT NULL,
  `PuntoCardinale` VARCHAR(2) NOT NULL,
		CHECK(PuntoCardinale IN ('N', 'NE', 'NW', 'S', 'SE', 'SW', 'E', 'W')),
  `Vano` INT NOT NULL,
  `Edificio` CHAR(5) NOT NULL,
  PRIMARY KEY (`Indice`, `Vano`, `Edificio`),
  INDEX `fk_finestra_vano1_idx` (`Vano` ASC, `Edificio` ASC) VISIBLE,
  CONSTRAINT `fk_finestra_vano1`
    FOREIGN KEY (`Vano` , `Edificio`)
    REFERENCES `Vano` (`NumeroVano` , `Edificio`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
KEY_BLOCK_SIZE = 1;


-- -----------------------------------------------------
-- Table `Passaggio`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Passaggio` ;

CREATE TABLE IF NOT EXISTS `Passaggio` (
  `Vano1` INT NOT NULL,
  `Vano2` INT NOT NULL,
  `Edificio` CHAR(5) NOT NULL,
  `Tipologia` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`Vano1`, `Edificio`, `Vano2`),
  INDEX `fk_vano_has_vano_vano2_idx` (`Vano2` ASC) VISIBLE,
  INDEX `fk_vano_has_vano_vano1_idx` (`Vano1` ASC, `Edificio` ASC) VISIBLE,
  CONSTRAINT `fk_vano_has_vano_vano1`
    FOREIGN KEY (`Vano1` , `Edificio`)
    REFERENCES `Vano` (`NumeroVano` , `Edificio`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_vano_has_vano_vano2`
    FOREIGN KEY (`Vano2`)
    REFERENCES `Vano` (`NumeroVano`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Accesso`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Accesso` ;

CREATE TABLE IF NOT EXISTS `Accesso` (
  `Identificativo` CHAR(6) NOT NULL,
  `Classificazione` VARCHAR(45) NOT NULL,
  `Larghezza` INT NOT NULL,
		CHECK(Larghezza > 0),
  `Lunghezza` INT NOT NULL,
		CHECK(Lunghezza > 0),
  `PuntoCardinale` VARCHAR(2) NULL,
		CHECK(PuntoCardinale IN ('N', 'NE', 'NW', 'S', 'SE', 'SW', 'E', 'W')),
  `CollegamentoEsterno` TINYINT NOT NULL,
  PRIMARY KEY (`Identificativo`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Varco`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Varco` ;

CREATE TABLE IF NOT EXISTS `Varco` (
  `Vano` INT NOT NULL,
  `Edificio` CHAR(5) NOT NULL,
  `Accesso` CHAR(6) NOT NULL,
  PRIMARY KEY (`Vano`, `Edificio`, `Accesso`),
  INDEX `fk_vano_has_accesso_accesso1_idx` (`Accesso` ASC) VISIBLE,
  INDEX `fk_vano_has_accesso_vano1_idx` (`Vano` ASC, `Edificio` ASC) VISIBLE,
  CONSTRAINT `fk_vano_has_accesso_vano1`
    FOREIGN KEY (`Vano` , `Edificio`)
    REFERENCES `Vano` (`NumeroVano` , `Edificio`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_vano_has_accesso_accesso1`
    FOREIGN KEY (`Accesso`)
    REFERENCES `Accesso` (`Identificativo`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Demarcazione`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Demarcazione` ;

CREATE TABLE IF NOT EXISTS `Demarcazione` (
  `Vano` INT NOT NULL,
  `Edificio` CHAR(5) NOT NULL,
  `Mura` CHAR(6) NOT NULL,
  PRIMARY KEY (`Vano`, `Edificio`, `Mura`),
  INDEX `fk_vano_has_mura_mura1_idx` (`Mura` ASC) VISIBLE,
  INDEX `fk_vano_has_mura_vano1_idx` (`Vano` ASC, `Edificio` ASC) VISIBLE,
  CONSTRAINT `fk_vano_has_mura_vano1`
    FOREIGN KEY (`Vano` , `Edificio`)
    REFERENCES `Vano` (`NumeroVano` , `Edificio`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_vano_has_mura_mura1`
    FOREIGN KEY (`Mura`)
    REFERENCES `Mura` (`Codice`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Danni`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Danni` ;

CREATE TABLE IF NOT EXISTS `Danni` (
  `Data` DATETIME NOT NULL,
  `Muratura` FLOAT NOT NULL,
		CHECK(Muratura > 0),
  `Infissi` FLOAT NOT NULL,
		CHECK(Infissi > 0),
  `Arredo` FLOAT NOT NULL,
		CHECK(Arredo > 0),
  `Edificio` CHAR(5) NOT NULL,
  PRIMARY KEY (`Data`, `Edificio`),
  INDEX `fk_danni_edificio1_idx` (`Edificio` ASC) VISIBLE,
  CONSTRAINT `fk_danni_edificio1`
    FOREIGN KEY (`Edificio`)
    REFERENCES `Edificio` (`Identificativo`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `EventoCalamitoso`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `EventoCalamitoso` ;

CREATE TABLE IF NOT EXISTS `EventoCalamitoso` (
  `Genere` VARCHAR(45) NOT NULL,
  `Datazione` DATETIME NOT NULL,
  PRIMARY KEY (`Genere`, `Datazione`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Rilevazione`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Rilevazione` ;

CREATE TABLE IF NOT EXISTS `Rilevazione` (
  `AreaGeogNumReg` INT NOT NULL,
  `AreaGeogCap` INT NOT NULL,
  `EventoCalamitosoGenere` VARCHAR(45) NOT NULL,
  `EventoCalamitosoData` DATETIME NOT NULL,
  `Gravita` varchar(45) NOT NULL,
  PRIMARY KEY (`AreaGeogNumReg`, `AreaGeogCap`, `EventoCalamitosoGenere`, `EventoCalamitosoData`),
  INDEX `fk_AreaGeografica_has_EventoCalamitoso_EventoCalamitoso1_idx` (`EventoCalamitosoGenere` ASC, `EventoCalamitosoData` ASC) VISIBLE,
  INDEX `fk_AreaGeografica_has_EventoCalamitoso_AreaGeografica1_idx` (`AreaGeogNumReg` ASC, `AreaGeogCap` ASC) VISIBLE,
  CONSTRAINT `fk_AreaGeografica_has_EventoCalamitoso_AreaGeografica1`
    FOREIGN KEY (`AreaGeogNumReg` , `AreaGeogCap`)
    REFERENCES `AreaGeografica` (`NumRegistrazione` , `Cap`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_AreaGeografica_has_EventoCalamitoso_EventoCalamitoso1`
    FOREIGN KEY (`EventoCalamitosoGenere` , `EventoCalamitosoData`)
    REFERENCES `EventoCalamitoso` (`Genere` , `Datazione`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ConsigliIntervento`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ConsigliIntervento` ;

CREATE TABLE IF NOT EXISTS `ConsigliIntervento` (
  `Lavoro` VARCHAR(100) NOT NULL,
  `CodicePriorita` INT NOT NULL,
		CHECK(CodicePriorita > 0),
  `Zona` VARCHAR(45) NOT NULL,
  `LimiteTemporale` VARCHAR(45) NOT NULL,
  `EventoCalamitoso` VARCHAR(45) NOT NULL,
  `Soglia` VARCHAR(45) NOT NULL,
  `Incidenza` FLOAT NOT NULL,
		CHECK(Incidenza > 0),
  `SpesaMancatoIntervento` INT NOT NULL,
		CHECK(SpesaMancatoIntervento > 0),
  `Edificio` CHAR(5) NOT NULL,
  PRIMARY KEY (`Lavoro`, `Edificio`),
  INDEX `fk_ConsigliIntervento_Edificio1_idx` (`Edificio` ASC) VISIBLE,
  CONSTRAINT `fk_ConsigliIntervento_Edificio1`
    FOREIGN KEY (`Edificio`)
    REFERENCES `Edificio` (`Identificativo`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Stato`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Stato` ;

CREATE TABLE IF NOT EXISTS `Stato` (
  `Data` DATETIME NOT NULL,
  `ParametriStrutturali` VARCHAR(45) NOT NULL,
  `ParametriClimatici` VARCHAR(45) NOT NULL,
  `EdificioIdentificativo` CHAR(5) NOT NULL,
  PRIMARY KEY (`Data`, `EdificioIdentificativo`),
  INDEX `fk_Stato_Edificio1_idx` (`EdificioIdentificativo` ASC) VISIBLE,
  CONSTRAINT `fk_Stato_Edificio1`
    FOREIGN KEY (`EdificioIdentificativo`)
    REFERENCES `Edificio` (`Identificativo`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ProgettoEdilizio`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `ProgettoEdilizio` ;

CREATE TABLE IF NOT EXISTS `ProgettoEdilizio` (
  `Codice` INT NOT NULL,
  `CodiceCatastaleComune` CHAR(4) NOT NULL,
  `DataPresentazione` DATE NOT NULL,
  `DataInizio` DATE NOT NULL,
  `DataApprovazione` DATE NOT NULL,
  `StimaDataFine` DATE NOT NULL,
  `Edificio` CHAR(5) NOT NULL,
  PRIMARY KEY (`Codice`, `CodiceCatastaleComune`),
  INDEX `fk_ProgettoEdilizio_Edificio1_idx` (`Edificio` ASC) VISIBLE,
  CONSTRAINT `fk_ProgettoEdilizio_Edificio1`
    FOREIGN KEY (`Edificio`)
    REFERENCES `Edificio` (`Identificativo`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `StadioAvanzamento`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `StadioAvanzamento` ;

CREATE TABLE IF NOT EXISTS `StadioAvanzamento` (
  `ID` INT NOT NULL,
  `DataInizio` DATE NOT NULL,
  `CostoFinale` FLOAT NULL,
		CHECK(CostoFinale > 0),
  `StimaTermine` DATE NOT NULL,
  `Budget` FLOAT NOT NULL,
		CHECK(Budget > 0),
  `DataCompletamento` DATE NULL,
  `ProgettoEdilizioCod` INT NOT NULL,
  `ProgettoEdilizioComune` CHAR(4) NOT NULL,
  PRIMARY KEY (`ID`),
  INDEX `fk_StadioAvanzamento_ProgettoEdilizio1_idx` (`ProgettoEdilizioCod` ASC, `ProgettoEdilizioComune` ASC) VISIBLE,
  CONSTRAINT `fk_StadioAvanzamento_ProgettoEdilizio1`
    FOREIGN KEY (`ProgettoEdilizioCod` , `ProgettoEdilizioComune`)
    REFERENCES `ProgettoEdilizio` (`Codice` , `CodiceCatastaleComune`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Lavoro`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Lavoro` ;

CREATE TABLE IF NOT EXISTS `Lavoro` (
  `Nome` VARCHAR(45) NOT NULL,
  `Inizio` DATE NOT NULL,
  `Termine` DATE NULL,
  `Costo` FLOAT NULL,
		CHECK(Costo > 0),
  `StadioAvanzamento` INT NOT NULL,
  PRIMARY KEY (`Nome`, `StadioAvanzamento`),
  INDEX `fk_Lavoro_StadioAvanzamento1_idx` (`StadioAvanzamento` ASC) VISIBLE,
  CONSTRAINT `fk_Lavoro_StadioAvanzamento1`
    FOREIGN KEY (`StadioAvanzamento`)
    REFERENCES `StadioAvanzamento` (`ID`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Lavoratore`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Lavoratore` ;

CREATE TABLE IF NOT EXISTS `Lavoratore` (
  `Matricola` INT NOT NULL,
  `Nome` VARCHAR(45) NOT NULL,
  `Cognome` VARCHAR(45) NOT NULL,
  `PagaOraria` INT NOT NULL,
		CHECK(PagaOraria > 0),
  `Ruolo` VARCHAR(45) NOT NULL,
  `AnnoInizio` INT NOT NULL,
  PRIMARY KEY (`Matricola`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Manodopera`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Manodopera` ;

CREATE TABLE IF NOT EXISTS `Manodopera` (
  `Lavoratore` INT NOT NULL,
  `Lavoro` VARCHAR(45) NOT NULL,
  `StadioAvanzamento` INT NOT NULL,
  PRIMARY KEY (`Lavoratore`, `Lavoro`, `StadioAvanzamento`),
  INDEX `fk_Lavoratore_has_Lavoro_Lavoro1_idx` (`Lavoro` ASC, `StadioAvanzamento` ASC) VISIBLE,
  INDEX `fk_Lavoratore_has_Lavoro_Lavoratore1_idx` (`Lavoratore` ASC) VISIBLE,
  CONSTRAINT `fk_Lavoratore_has_Lavoro_Lavoratore1`
    FOREIGN KEY (`Lavoratore`)
    REFERENCES `Lavoratore` (`Matricola`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Lavoratore_has_Lavoro_Lavoro1`
    FOREIGN KEY (`Lavoro` , `StadioAvanzamento`)
    REFERENCES `Lavoro` (`Nome` , `StadioAvanzamento`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Calendario`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Calendario` ;

CREATE TABLE IF NOT EXISTS `Calendario` (
  `GiornoEdOrario` DATETIME NOT NULL,
  `Durata` INT NOT NULL,
		CHECK(Durata > 0),
  `Mansione` VARCHAR(45) NOT NULL,
  `IdSupervisore` INT NULL,
  `Lavoratore` INT NOT NULL,
  PRIMARY KEY (`GiornoEdOrario`, `Lavoratore`),
  INDEX `fk_Calendario_Lavoratore1_idx` (`Lavoratore` ASC) VISIBLE,
  CONSTRAINT `fk_Calendario_Lavoratore1`
    FOREIGN KEY (`Lavoratore`)
    REFERENCES `Lavoratore` (`Matricola`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Materiale`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Materiale` ;

CREATE TABLE IF NOT EXISTS `Materiale` (
  `CodiceLotto` INT NOT NULL,
  `Nome` VARCHAR(45) NOT NULL,
  `Fornitore` VARCHAR(45) NOT NULL,
  `DataAcquisto` DATE NOT NULL,
  `Costo` FLOAT NOT NULL,
		CHECK(Costo > 0),
  `UnitaDiMisura` VARCHAR(20) NOT NULL,
  `Composizione` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`CodiceLotto`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Occorrenza`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Occorrenza` ;

CREATE TABLE IF NOT EXISTS `Occorrenza` (
  `Lavoro` VARCHAR(45) NOT NULL,
  `StadioAvanzamento` INT NOT NULL,
  `Materiale` INT NOT NULL,
  `PercUtilizzo` FLOAT NOT NULL,
		CHECK(PercUtilizzo > 0),
  PRIMARY KEY (`Lavoro`, `StadioAvanzamento`, `Materiale`),
  INDEX `fk_Lavoro_has_Materiale_Materiale1_idx` (`Materiale` ASC) VISIBLE,
  INDEX `fk_Lavoro_has_Materiale_Lavoro1_idx` (`Lavoro` ASC, `StadioAvanzamento` ASC) VISIBLE,
  CONSTRAINT `fk_Lavoro_has_Materiale_Lavoro1`
    FOREIGN KEY (`Lavoro` , `StadioAvanzamento`)
    REFERENCES `Lavoro` (`Nome` , `StadioAvanzamento`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Lavoro_has_Materiale_Materiale1`
    FOREIGN KEY (`Materiale`)
    REFERENCES `Materiale` (`CodiceLotto`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Piastrella`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Piastrella` ;

CREATE TABLE IF NOT EXISTS `Piastrella` (
  `MaterialeAdesivo` VARCHAR(45) NOT NULL,
  `LarghezzaFuga` FLOAT NOT NULL,
		CHECK(LarghezzaFuga > 0),
  `Disegno` VARCHAR(45) NOT NULL,
		CHECK(Disegno IN ('naturale', 'stampato')),
  `Forma` VARCHAR(45) NOT NULL,
  `Larghezza` FLOAT NOT NULL,
		CHECK(Larghezza > 0),
  `Lunghezza` FLOAT NOT NULL,
		CHECK(Lunghezza > 0),
  `Spessore` FLOAT NOT NULL,
		CHECK(Spessore > 0),
  `CodiceLotto` INT NOT NULL,
  PRIMARY KEY (`CodiceLotto`),
  CONSTRAINT `fk_Piastrella_Materiale1`
    FOREIGN KEY (`CodiceLotto`)
    REFERENCES `Materiale` (`CodiceLotto`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `AltriMateriali`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `AltriMateriali` ;

CREATE TABLE IF NOT EXISTS `AltriMateriali` (
  `Lunghezza` FLOAT NOT NULL,
		CHECK(Lunghezza > 0),
  `Altezza` FLOAT NOT NULL,
		CHECK(Altezza > 0),
  `Larghezza` FLOAT NOT NULL,
		CHECK(Larghezza > 0),
  `CodiceLotto` INT NOT NULL,
  PRIMARY KEY (`CodiceLotto`),
  CONSTRAINT `fk_AltriMateriali_Materiale1`
    FOREIGN KEY (`CodiceLotto`)
    REFERENCES `Materiale` (`CodiceLotto`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Mattone`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Mattone` ;

CREATE TABLE IF NOT EXISTS `Mattone` (
  `Alveolatura` VARCHAR(45) NULL,
  `Forma` VARCHAR(45) NOT NULL,
  `Riempimento` VARCHAR(45) NOT NULL,
  `Modello` VARCHAR(45) NOT NULL,
  `Lunghezza` FLOAT NOT NULL,
		CHECK(Lunghezza > 0),
  `Larghezza` FLOAT NOT NULL,
		CHECK(larghezza > 0),
  `Spessore` FLOAT NOT NULL,
		CHECK(Spessore > 0),
  `CodiceLotto` INT NOT NULL,
  PRIMARY KEY (`CodiceLotto`),
  CONSTRAINT `fk_Mattone_Materiale1`
    FOREIGN KEY (`CodiceLotto`)
    REFERENCES `Materiale` (`CodiceLotto`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `PietreOssatura`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `PietreOssatura` ;

CREATE TABLE IF NOT EXISTS `PietreOssatura` (
  `Spessore` FLOAT NOT NULL,
		CHECK(Spessore > 0),
  `Larghezza` FLOAT NOT NULL,
		CHECK(Larghezza > 0),
  `Lunghezza` FLOAT NOT NULL,
		CHECK(Lunghezza > 0),
  `CodiceLotto` INT NOT NULL,
  PRIMARY KEY (`CodiceLotto`),
  CONSTRAINT `fk_PietreOssatura_Materiale1`
    FOREIGN KEY (`CodiceLotto`)
    REFERENCES `Materiale` (`CodiceLotto`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `PietreCopertura`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `PietreCopertura` ;

CREATE TABLE IF NOT EXISTS `PietreCopertura` (
  `PesoMedio` FLOAT NOT NULL,
		CHECK(PesoMedio > 0),
  `SuperficieMedia` FLOAT NOT NULL,
		CHECK(SuperficieMedia > 0),
  `Disposizione` VARCHAR(45) NOT NULL,
		CHECK(Disposizione IN ('orizzontale', 'verticale', 'naturale')),
  `CodiceLotto` INT NOT NULL,
  PRIMARY KEY (`CodiceLotto`),
  CONSTRAINT `fk_PietreCopertura_Materiale1`
    FOREIGN KEY (`CodiceLotto`)
    REFERENCES `Materiale` (`CodiceLotto`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Intonaco`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Intonaco` ;

CREATE TABLE IF NOT EXISTS `Intonaco` (
  `CodiceLotto` INT NOT NULL,
  PRIMARY KEY (`CodiceLotto`),
  CONSTRAINT `fk_Intonaco_Materiale1`
    FOREIGN KEY (`CodiceLotto`)
    REFERENCES `Materiale` (`CodiceLotto`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Pavimentazione`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Pavimentazione` ;

CREATE TABLE IF NOT EXISTS `Pavimentazione` (
  `Piastrella` INT NOT NULL,
  `Vano` INT NOT NULL,
  `Edificio` CHAR(5) NOT NULL,
  PRIMARY KEY (`Piastrella`, `Vano`, `Edificio`),
  INDEX `fk_Piastrella_has_Vano_Vano1_idx` (`Vano` ASC, `Edificio` ASC) VISIBLE,
  INDEX `fk_Piastrella_has_Vano_Piastrella1_idx` (`Piastrella` ASC) VISIBLE,
  CONSTRAINT `fk_Piastrella_has_Vano_Piastrella1`
    FOREIGN KEY (`Piastrella`)
    REFERENCES `Piastrella` (`CodiceLotto`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Piastrella_has_Vano_Vano1`
    FOREIGN KEY (`Vano` , `Edificio`)
    REFERENCES `Vano` (`NumeroVano` , `Edificio`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Impiego`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Impiego` ;

CREATE TABLE IF NOT EXISTS `Impiego` (
  `AltriMateriali` INT NOT NULL,
  `Vano` INT NOT NULL,
  `Edificio` CHAR(5) NOT NULL,
  PRIMARY KEY (`AltriMateriali`, `Vano`, `Edificio`),
  INDEX `fk_AltriMateriali_has_Vano_Vano1_idx` (`Vano` ASC, `Edificio` ASC) VISIBLE,
  INDEX `fk_AltriMateriali_has_Vano_AltriMateriali1_idx` (`AltriMateriali` ASC) VISIBLE,
  CONSTRAINT `fk_AltriMateriali_has_Vano_AltriMateriali1`
    FOREIGN KEY (`AltriMateriali`)
    REFERENCES `AltriMateriali` (`CodiceLotto`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_AltriMateriali_has_Vano_Vano1`
    FOREIGN KEY (`Vano` , `Edificio`)
    REFERENCES `Vano` (`NumeroVano` , `Edificio`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Struttura`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Struttura` ;

CREATE TABLE IF NOT EXISTS `Struttura` (
  `Mattone` INT NOT NULL,
  `Mura` CHAR(6) NOT NULL,
  PRIMARY KEY (`Mattone`, `Mura`),
  INDEX `fk_Mattone_has_Mura_Mura1_idx` (`Mura` ASC) VISIBLE,
  INDEX `fk_Mattone_has_Mura_Mattone1_idx` (`Mattone` ASC) VISIBLE,
  CONSTRAINT `fk_Mattone_has_Mura_Mattone1`
    FOREIGN KEY (`Mattone`)
    REFERENCES `Mattone` (`CodiceLotto`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Mattone_has_Mura_Mura1`
    FOREIGN KEY (`Mura`)
    REFERENCES `Mura` (`Codice`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Costruzione`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Costruzione` ;

CREATE TABLE IF NOT EXISTS `Costruzione` (
  `PietreOssatura` INT NOT NULL,
  `Mura` CHAR(6) NOT NULL,
  PRIMARY KEY (`PietreOssatura`, `Mura`),
  INDEX `fk_PietreOssatura_has_Mura_Mura1_idx` (`Mura` ASC) VISIBLE,
  INDEX `fk_PietreOssatura_has_Mura_PietreOssatura1_idx` (`PietreOssatura` ASC) VISIBLE,
  CONSTRAINT `fk_PietreOssatura_has_Mura_PietreOssatura1`
    FOREIGN KEY (`PietreOssatura`)
    REFERENCES `PietreOssatura` (`CodiceLotto`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_PietreOssatura_has_Mura_Mura1`
    FOREIGN KEY (`Mura`)
    REFERENCES `Mura` (`Codice`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Decorazione`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Decorazione` ;

CREATE TABLE IF NOT EXISTS `Decorazione` (
  `PietreCopertura` INT NOT NULL,
  `Mura` CHAR(6) NOT NULL,
  PRIMARY KEY (`PietreCopertura`, `Mura`),
  INDEX `fk_PietreCopertura_has_Mura_Mura1_idx` (`Mura` ASC) VISIBLE,
  INDEX `fk_PietreCopertura_has_Mura_PietreCopertura1_idx` (`PietreCopertura` ASC) VISIBLE,
  CONSTRAINT `fk_PietreCopertura_has_Mura_PietreCopertura1`
    FOREIGN KEY (`PietreCopertura`)
    REFERENCES `PietreCopertura` (`CodiceLotto`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_PietreCopertura_has_Mura_Mura1`
    FOREIGN KEY (`Mura`)
    REFERENCES `Mura` (`Codice`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `Rivestimento`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `Rivestimento` ;

CREATE TABLE IF NOT EXISTS `Rivestimento` (
  `Intonaco` INT NOT NULL,
  `Mura` CHAR(6) NOT NULL,
  `NumeroStrato` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`Intonaco`, `Mura`),
  INDEX `fk_Intonaco_has_Mura_Mura1_idx` (`Mura` ASC) VISIBLE,
  INDEX `fk_Intonaco_has_Mura_Intonaco1_idx` (`Intonaco` ASC) VISIBLE,
  CONSTRAINT `fk_Intonaco_has_Mura_Intonaco1`
    FOREIGN KEY (`Intonaco`)
    REFERENCES `Intonaco` (`CodiceLotto`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Intonaco_has_Mura_Mura1`
    FOREIGN KEY (`Mura`)
    REFERENCES `Mura` (`Codice`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;