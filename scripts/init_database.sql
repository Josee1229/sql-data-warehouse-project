/*
===============================================================================
CREATE DATABASE
===============================================================================
Script Purpose:
    This script creates a new database named 'DataWarehous' after checking if it already exists.
    If the database exists, it is dropped and recreated.

WARNING:
    Running this script will drop the entire 'DataWarehouse' database if it exists.
    ALL data in the database will be permanently deleted. Proceed with caution and ensure you have proper backups before running this script.
*/


DROP DATABASE IF EXISTS DataWarehouse;

CREATE DATABASE DataWarehouse;

USE DataWarehouse;
