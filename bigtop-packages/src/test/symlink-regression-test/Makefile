#Override the PARCEL_LIBDIR as needed when regenerating the conversions file
PARCEL_LIBDIR=/root/sampleParcel/CDH-5.4.0-1.cdh5.5.0.p0.836/lib

MYDIR=$(shell pwd)

#This Makefile can be used for testing the "strip_versions" function in 
#packaging_functions.sh.  The Make rules below are self-explanatory
#strip_versions outputs three types of lines starting with Pass|Fail|Original
#At present we are only testing the strip_versions function with most
#internal_versionless symlinks as input (we do not have the external_versionless_symlink data yet)

#Use this Makefile when making changes to the strip_versions code to make sure
#nothing has regressed.  In case of behavior change, make sure that the
#rule to generate the test data is also modified if feasible and that the 
#test data too is changed

#Typical usage : make test 
test:internal_test external_test custom_test
internal_test: internal_symlinks.dat
	cat internal_symlinks.dat | ./strip_version_test.sh | (grep -i ^fail ; test $$? -eq 1 )
external_test: external_symlinks.dat
	cat external_symlinks.dat | ./strip_version_test.sh |  (grep -i ^fail ; test $$? -eq 1 )
custom_test: custom_symlinks.dat
	cat custom_symlinks.dat | ./strip_version_test.sh |  (grep -i ^fail ; test $$? -eq 1 )

help:
	echo "Try make PARCEL_LIBDIR=<location of your parcels/lib>"

#Regenerate internal versionless symlinks data file, including accounting for
#exceptions we have put in for pig and avro.  Note that the generated data file
#is also being checked into source - the rule below is just a convenience target
#that might be useful if someone wants to recreate the data file but it is not
#meant to be regenerated on the fly
iv_data:
	rm -f $(MYDIR)/internal_symlinks
	 cd $(PARCEL_LIBDIR) ; find . -type l -exec ls -l {} \; | \
     awk '$$11 ~ /^[a-zA-Z]+.*jar/{printf "%s|%s\n", $$9, $$11}' | \
     grep -v 'pig.jar.*withouthadoop' | \
     grep -v 'hadoop-0.20-mapreduce/hadoop-examples.jar' | \
     grep -v 'avro-mapred-1.7.6-cdh5.4.0-SNAPSHOT-hadoop2.jar' > $(MYDIR)/internal_symlinks
