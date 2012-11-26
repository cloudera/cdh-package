# Set CATALINA_BASE to:
#   /usr/lib/sqoop/sqoop-server for YARN clusters
#   /usr/lib/sqoop/sqoop-server-0.20 for MR1 clusters
export CATALINA_BASE=${CATALINA_BASE:-"/usr/lib/sqoop/sqoop-server"}
