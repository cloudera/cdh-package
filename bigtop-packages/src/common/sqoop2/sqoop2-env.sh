# Set CATALINA_BASE to:
#   /usr/lib/sqoop2/sqoop2-server for YARN clusters
#   /usr/lib/sqoop2/sqoop2-server-0.20 for MR1 clusters
export CATALINA_BASE=${CATALINA_BASE:-"/usr/lib/sqoop2/sqoop2-server"}
