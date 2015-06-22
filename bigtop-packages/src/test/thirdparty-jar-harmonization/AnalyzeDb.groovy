#!/usr/bin/env groovy
// Copyright (c) 2015 Cloudera, Inc. All rights reserved.

import java.util.jar.JarFile;
import groovy.sql.Sql;
import groovy.json.JsonSlurper;
import java.io.FileNotFoundException;
import java.io.File;

/*
 *  After each parcel is downloaded and analyzed, the following tables are updated:
 *  Database: thirdparty_harmonization
 *  Tables  : thirdparty_jars_stats, thirdparty_jars_component_map and corresponding history tables.
 *  Server  : mthtest3.ent.cloudera.com
 *
 *  The queries in this script serve to answer questions about possible proliferation of thirdparty jars.
 #  The tables mentioned above are queried and the Jenkins job http://systest.jenkins.cloudera.com/job/Third-Party-Jar-Harmonization/
 *  fails if the the following conditions are met.
 *
 *  1. If there has been a recent proliferation of thirdparty jars. i.e; if there were
 *     6 different versions of foo.jar identified in the last run of the job mentioned above and now,
 *     the latest run has detected 7.
 *  2. This case is more unlikely, but, it also checks if there is a new jar that that is introduced
 *     between two successive runs which happens to have more than one version.
 *
 *  How does the output of this script break the build:
 *  At the end of the run, the Jenkins job validates that the file analysis.txt if present is actually empty. If not, then the
 *  build breaks triggering an email with the contents of the text file.
 *
 */
public class AnalyzeDb {

  public static void main(String[] args) {

    // If args[0] is null, then terminate.
    if(args.size() != 2) {
      throw new Exception("Need to pass two parameters. The first being the log file name and the second the CDH version. ex AnalyzeDb.groovy analysis.txt CDH-5.4.3")
    }

    def analysis_file=args[0];
    def cdh_version = args[1];

    def sqlConnection = Utility.getDbConnection();
    sqlConnection.execute("USE thirdparty_harmonization")

    File analysisFile = new File("./"+analysis_file);

    PrintWriter analysisFileWriter = new PrintWriter(analysisFile)
    def lineSeperator="\n-------------------------------------------------------\n"

    try {
      // New Jars that have duplicates.
      def new_jars= "SELECT js.* FROM thirdparty_jars_stats js" +
                     " LEFT OUTER JOIN thirdparty_jars_stats_history jsh" +
                     " ON (js.jar_name=jsh.jar_name AND js.cdh_version=jsh.cdh_version AND jsh.run_date=(SELECT max(run_date) from thirdparty_jars_stats_history where cdh_version=?))" +
                     " where jsh.jar_name is NULL AND js.cdh_version=? ;"

      def rowSet=sqlConnection.rows (new_jars, cdh_version, cdh_version)
      if (rowSet.size() > 0) {
          analysisFileWriter.println(lineSeperator)
          analysisFileWriter.println("List of new jars that have duplicates now. These did not exist in the previously.")
          rowSet.each { rows ->
              analysisFileWriter.println("${rows.run_date},${rows.jar_name},${rows.jar_unique_count},${rows.jar_search_pattern},${rows.jar_version_names}")
          }
      }

      // Find all jars where an increase the number of versions is identified.
      // This is relative to the last successful run.
      def increased_count= "SELECT js.cdh_version,js.parcel_name,js.jar_name, js.jar_unique_count, js.jar_version_names, " +
        "jsh.parcel_name as new_parcel, jsh.jar_unique_count as new_count, jsh.jar_version_names as extended_versions "+
        "FROM thirdparty_jars_stats js " +
        "INNER JOIN thirdparty_jars_stats_history jsh " +
        "ON (js.jar_name=jsh.jar_name AND js.cdh_version=jsh.cdh_version " +
        "AND jsh.run_date=(SELECT max(run_date) from thirdparty_jars_stats_history where cdh_version=?)) " +
        "WHERE js.jar_unique_count > jsh.jar_unique_count AND js.cdh_version=? ;"

      rowSet=sqlConnection.rows (increased_count, cdh_version, cdh_version)
      if (rowSet.size() > 0) {
          analysisFileWriter.println(lineSeperator)
          analysisFileWriter.println("List of jars where there is an increase in the number of duplicates.")
          rowSet.each { rows ->
              analysisFileWriter.println("${rows.cdh_version},${rows.parcel_name},${rows.jar_name},${rows.jar_unique_count},${rows.jar_version_names},${rows.new_parcel}, ${rows.new_count}, ${rows.extended_versions}")
          }

          // Find all components which potentially added the same jar with a new version.
          def component= "SELECT jcm.* FROM thirdparty_jars_component_map jcm" +
                         " LEFT OUTER JOIN thirdparty_jars_component_map_history jcmh" +
                         " ON (jcm.jar_name=jcmh.jar_name AND jcm.component_name=jcmh.component_name AND jcmh.run_date=(SELECT max(run_date) from thirdparty_jars_component_map_history where cdh_version=?))" +
                         " where jcmh.jar_name is NULL AND jcm.cdh_version=? ;"

          rowSet=sqlConnection.rows (component, cdh_version, cdh_version)
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

    // Finally ensure that all data has been moved into history tables.
    def utilityClass = new Utility()
    utilityClass.insertIntoHistoryTables()
  }
}
