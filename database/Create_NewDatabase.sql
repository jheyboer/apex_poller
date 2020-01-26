CREATE DATABASE IF NOT EXISTS apex;
USE apex;


-- Update user account below
CREATE USER 'apex'@'localhost' IDENTIFIED BY '1234';
GRANT ALL PRIVILEGES ON apex.* TO 'apex'@'localhost';






--- No other changes needed below
FLUSH PRIVILEGES;
CREATE TABLE `device` (
  `deviceid` int NOT NULL AUTO_INCREMENT,
  `device_name` varchar(55) NOT NULL,
  `device_ip` varchar(60) NOT NULL,
  `user` varchar(30) DEFAULT NULL,
  `password` varchar(30) DEFAULT NULL,
  `detected_name` varchar(30) DEFAULT NULL,
  `detected_serial` varchar(45) DEFAULT NULL,
  `detected_software` varchar(20) DEFAULT NULL,
  `detected_hardware` varchar(45) DEFAULT NULL,
  `deactivated_date` datetime DEFAULT NULL,
  PRIMARY KEY (`deviceid`),
  UNIQUE KEY `deviceid_UNIQUE` (`deviceid`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE `history_device` (
  `historydeviceid` int NOT NULL AUTO_INCREMENT,
  `deviceid` int NOT NULL,
  `detected_name` varchar(45) DEFAULT NULL,
  `detected_serial` varchar(45) DEFAULT NULL,
  `detected_hardware` varchar(45) DEFAULT NULL,
  `detected_software` varchar(45) DEFAULT NULL,
  `last_power_fail` datetime DEFAULT NULL,
  `last_power_restore` datetime DEFAULT NULL,
  `poll_date` datetime NOT NULL,
  PRIMARY KEY (`historydeviceid`)
) ENGINE=InnoDB AUTO_INCREMENT=41 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE `history_outlets` (
  `historyoutletid` int NOT NULL AUTO_INCREMENT,
  `apexid` int NOT NULL,
  `outlet_name` varchar(45) NOT NULL,
  `outlet_state` varchar(45) DEFAULT NULL,
  `outlet_xstatus` varchar(45) DEFAULT NULL,
  `outlet_outputid` int DEFAULT NULL,
  `outlet_polldate` datetime DEFAULT NULL,
  PRIMARY KEY (`historyoutletid`)
) ENGINE=InnoDB AUTO_INCREMENT=89 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE `history_probes` (
  `historyprobeid` int NOT NULL AUTO_INCREMENT,
  `deviceid` int NOT NULL,
  `probe_name` varchar(45) DEFAULT NULL,
  `probe_type` varchar(45) DEFAULT NULL,
  `probe_value` decimal(10,2) DEFAULT NULL,
  `polldate` datetime NOT NULL,
  PRIMARY KEY (`historyprobeid`)
) ENGINE=InnoDB AUTO_INCREMENT=341 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE `logging` (
  `loggingid` int NOT NULL AUTO_INCREMENT,
  `deviceid` int NOT NULL,
  `severity` int NOT NULL,
  `messagetype` varchar(120) NOT NULL,
  `message` text NOT NULL,
  `timestamp` varchar(45) NOT NULL,
  `acknowledge` int DEFAULT NULL,
  PRIMARY KEY (`loggingid`)
) ENGINE=InnoDB AUTO_INCREMENT=852 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


DELIMITER $$
CREATE DEFINER=`root`@`localhost` PROCEDURE `get_activedevices`()
BEGIN
SELECT deviceid, device_name, device_ip, user, password, detected_serial, detected_software
FROM apex.device
where deactivated_date is null
;
END$$
DELIMITER ;
