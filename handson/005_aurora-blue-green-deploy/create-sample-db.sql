-- データベースの作成
CREATE DATABASE `test-db`;

-- 新しいデータベースに接続
USE `test-db`;

-- 社員情報を格納するテーブルの作成
CREATE TABLE `employees` (
    `employee_id` INT NOT NULL AUTO_INCREMENT,
    `employee_name` VARCHAR(100) NOT NULL,
    PRIMARY KEY (`employee_id`)
);

-- テストデータの挿入（オプション）
INSERT INTO `employees` (`employee_name`) VALUES ('hogehoge');
INSERT INTO `employees` (`employee_name`) VALUES ('fugafuga');