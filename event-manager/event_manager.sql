-- Host: 127.0.0.1    Database: event_db
-- ------------------------------------------------------
-- Server version	5.6.16

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `email` varchar(50) NOT NULL,
  `name` varchar(50) NOT NULL,
  `company` varchar(50) NOT NULL,
  `response` tinyint(4) DEFAULT NULL,
  PRIMARY KEY (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

INSERT INTO `users` VALUES ('jwick@email.com','John Wick','Mitra Innovation',0),('test1@test.com','Test1','Test1 Com',1),('test2@test.com','Test2','Test1 Com',0),('test3@test.com','Test3','Test1 Com',0),('test4@test.com','Test4','Test1 Com',1);
