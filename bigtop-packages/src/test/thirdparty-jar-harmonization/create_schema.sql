-- Database to use
create database thirdparty_harmonization;

use thirdparty_harmonization;

-- Holds current run information
create table thirdparty_jars_stats(
run_date datetime not null,
jar_name varchar(255) not null,
jar_unique_count smallint not null,
jar_search_pattern varchar(255) not null,
jar_version_names Text not null,
PRIMARY KEY(run_date,jar_name)
);

-- Holds information about previous runs.
-- Each time a new run happens, data from thirdparty_jars_stats is moved down 
-- to the history table before thirdparty_jars_stats is populated with new data.
create table thirdparty_jars_stats_history(
run_date datetime not null,
jar_name varchar(255) not null,
jar_unique_count smallint not null,
jar_search_pattern varchar(255) not null,
jar_version_names Text not null,
PRIMARY KEY(run_date,jar_name)
);

-- Holds information from the current run.
-- Has information about the jar, and which components rely on which version.
-- ex: 
-- foo.jar hadoop
-- foo.jar oozie
create table thirdparty_jars_component_map(
run_date datetime not null,
jar_name varchar(255) not null,
component_name varchar(255) not null,
jar_with_versions Text not null,
PRIMARY KEY(run_date,jar_name,component_name)
);

-- This is the backup for thirdparty_jars_component_map. Each run, data from
-- thirdparty_jars_component_map is copied over to this table, and new data 
-- from the most recent run is pushed into  thirdparty_jars_component_map.
create table thirdparty_jars_component_map_history(
run_date datetime not null,
jar_name varchar(255) not null,
component_name varchar(255) not null,
jar_with_versions Text not null,
PRIMARY KEY(run_date,jar_name,component_name)
);
