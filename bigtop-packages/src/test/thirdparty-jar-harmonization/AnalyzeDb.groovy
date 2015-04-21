#!/usr/bin/env groovy

import java.util.jar.JarFile;
import groovy.sql.Sql;
import groovy.json.JsonSlurper;
import java.io.FileNotFoundException;
import java.io.File;

public class AnalyzeDb {

  public static void main(String[] args) {
    
    // Check if the properties file that contains connection info is present.
    File dbPropertiesFile=new File("./DbConnection.json");
    if(! dbPropertiesFile.exists()) {
      throw new FileNotFoundException("DbConnection.json file not found.");
    }

    def dbPropertiesJson = new JsonSlurper().parseText(dbPropertiesFile.text);

    def sqlConnection = Sql.newInstance(dbPropertiesJson."connectionString", dbPropertiesJson."userName", dbPropertiesJson."password", dbPropertiesJson."driver")
    sqlConnection.execute("USE thirdparty_harmonization")
    
    // Making sure that the file is deleted if it is already present.
    File analysisFile = new File("./analysis.txt");
    analysisFile.delete();

    PrintWriter analysisFileWriter = new PrintWriter(analysisFile)
    def lineSeperator="\n-------------------------------------------------------\n"

    try {
      // New Jars that have duplicates.
      def new_jars= "SELECT js.* FROM thirdparty_jars_stats js" +
                     " LEFT OUTER JOIN thirdparty_jars_stats_history jsh" +
                     " ON (js.jar_name=jsh.jar_name AND jsh.run_date=(SELECT max(run_date) from thirdparty_jars_stats_history))" +
                     " where jsh.jar_name is NULL;"

      def rowSet=sqlConnection.rows ("${Sql.expand(new_jars)}")
      if (rowSet.size() > 0) {
          analysisFileWriter.println(lineSeperator)
          analysisFileWriter.println("List of new jars that have duplicates now. These did not exist in the previously.")
          rowSet.each { rows ->
              analysisFileWriter.println("${rows.run_date},${rows.jar_name},${rows.jar_unique_count},${rows.jar_search_pattern},${rows.jar_version_names}")
          }
      }

      // Find all jars where an increase the number of versions is identified.
      // This is relative to the last successful run.
      def increased_count= "SELECT js.* FROM thirdparty_jars_stats js" +
                           " INNER JOIN thirdparty_jars_stats_history jsh" +
                           " ON (js.jar_name=jsh.jar_name AND jsh.run_date=(SELECT max(run_date) from thirdparty_jars_stats_history))" +
                           " WHERE js.jar_unique_count > jsh.jar_unique_count;"

      rowSet=sqlConnection.rows ("${Sql.expand(increased_count)}")
      if (rowSet.size() > 0) {
          analysisFileWriter.println(lineSeperator)
          analysisFileWriter.println("List of jars where there is an increase in the number of duplicates.")
          rowSet.each { rows ->
              analysisFileWriter.println("${rows.run_date},${rows.jar_name},${rows.jar_unique_count},${rows.jar_search_pattern},${rows.jar_version_names}")
          }

          // Find all components which potentially added the same jar with a new version.
          def component= "SELECT jcm.* FROM thirdparty_jars_component_map jcm" +
                         " LEFT OUTER JOIN thirdparty_jars_component_map_history jcmh" +
                         " ON (jcm.jar_name=jcmh.jar_name AND jcm.component_name=jcmh.component_name AND jcmh.run_date=(SELECT max(run_date) from thirdparty_jars_component_map_history))" +
                         " where jcmh.jar_name is NULL;"

          rowSet=sqlConnection.rows ("${Sql.expand(component)}")
          if (rowSet.size() > 0) {
              analysisFileWriter.println(lineSeperator)
              analysisFileWriter.println("Potentially new componenets where the proliferation has occured. Mapping component with the jar name that has the duplicate.")
              rowSet.each { rows ->
                analysisFileWriter.println("${rows.run_date},${rows.jar_name},${rows.component_name},${rows.jar_with_versions}")
              }
          }
      }
    }
    finally {
       try {
           sqlConnection.close();
           analysisFileWriter.close();
       } catch (Exception e) {
         // At this point just swallow the exception. Nothing to do.
	 println e.printStackTrace();
       } 
    }
  }
}
