#!/usr/bin/env groovy
// Copyright (c) 2015 Cloudera, Inc. All rights reserved.

import groovy.sql.Sql
import java.sql.SQLException;
import groovy.json.JsonSlurper;

// Utility class
public class Utility {
  
  // Get db connection
  public static Sql getDbConnection() {
    // Check if the properties file that contains connection info is present.
    File dbPropertiesFile=new File("./DbConnection.json");
    if(! dbPropertiesFile.exists()) {
      throw new FileNotFoundException("DbConnection.json file not found.");
    }

    def dbPropertiesJson = new JsonSlurper().parseText(dbPropertiesFile.text);
    return Sql.newInstance(dbPropertiesJson."connectionString", dbPropertiesJson."userName", dbPropertiesJson."password", dbPropertiesJson."driver")
  }
  
  // Move all data into history tables and truncate temp tables
  public static void insertIntoHistoryTables() {
      
      Exception exception = null;
      def db = getDbConnection()
      try {
        
        db.execute ("USE thirdparty_harmonization");
        // Backing up information into the history tables.
        db.execute ("INSERT INTO thirdparty_jars_stats_history SELECT * FROM thirdparty_jars_stats;")
        db.execute ("INSERT INTO thirdparty_jars_component_map_history SELECT * FROM thirdparty_jars_component_map;")

        // Now, truncate the table that holds information about the "current" run.
        db.execute ("TRUNCATE TABLE thirdparty_jars_stats;")
        db.execute ("TRUNCATE TABLE thirdparty_jars_component_map;")
      } catch (SQLException e) {
        exception = e;
      } finally {
        if (db != null) {
          try {
            db.close();
          } catch (Exception e) {
            // Nothing to do.
            println(e.printStackTrace())
          }
        }
      }

      // Throw exception if any.
      if (exception != null) {
        throw exception;
      }
  }

    /*
     *  Given a String array, return a concatenated string separated by the passed in separator.
     *
     *  @param arr : list of strings that need to be concatenated.
     *  @param separator: Seprate concatenated strings with this value.  
     */
    public static String constructStringFromList(List<String> arr, String separator) {
      
      if(separator == null || separator.isEmpty()) {
        throw new IllegalArgumentException("separator argument cannot be empty");
      }
      
      if(arr == null || arr.isEmpty()) {
        throw new IllegalArgumentException("The array list, arr, cannot be empty");
      }
      
      StringBuilder result = new StringBuilder();
      for(String string : arr) {
          result.append(string);
          result.append(separator);
      }
      def resultStr = result.length() > 0 ? result.substring(0, result.length() - separator.length()): "";
      
      return resultStr;
    }
}
