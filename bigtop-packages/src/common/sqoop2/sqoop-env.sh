# Set CATALINA_BASE to:
#   /usr/lib/sqoop2/sqoop-server for YARN clusters
#   /usr/lib/sqoop2/sqoop-server-0.20 for MR1 clusters
export CATALINA_BASE=${CATALINA_BASE:-"/usr/lib/sqoop2/sqoop-server"}
