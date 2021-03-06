#!/bin/bash
jsonfile=$1
echo "spin up the mongodb cluster"
cd mongodb_server
./install.sh
cd ..
echo "import ${jsonfile} into NonShardedCollection using mongoimport"
docker run -v $(pwd)/sampledata:/sampledata -it --rm --network mongo_network mongo mongoimport --host=mongos1,mongos2 --db=testDb --collection=NonShardedCollection --mode=merge --upsertFields=_id  --file=/sampledata/${jsonfile}
echo "import ${jsonfile} into ShardedCollection using mongoimport"
docker run -v $(pwd)/sampledata:/sampledata -it --rm --network mongo_network mongo mongoimport --host=mongos1,mongos2 --db=testDb --collection=ShardedCollection --mode=merge --upsertFields=_id,shardingField  --file=/sampledata/${jsonfile}
echo "Build an image for a dockerised spark server"
docker build -f ./docker_spark_server/Dockerfile -t spark3.0.1-scala2.12-hadoop3.2.1 ./docker_spark_server
echo "Build the spark application"
docker run -e MAVEN_OPTS="-Xmx1024M -Xss128M -XX:MetaspaceSize=512M -XX:MaxMetaspaceSize=1024M -XX:+CMSClassUnloadingEnabled" --rm -v "${PWD}":/usr/src/mymaven -v "${HOME}/.m2":/root/.m2 -w /usr/src/mymaven maven:3.6.3-jdk-8 mvn clean install
echo "Run the Spark application using the dockerised spark server to import ${jsonfile} into SparkNonShardedCollection"
docker run -v $(pwd)/sampledata:/sampledata  -v $(pwd)/target:/target -it --rm --network mongo_network  spark3.0.1-scala2.12-hadoop3.2.1:latest spark-submit --deploy-mode client --class org.example.App /target/simplespark-1.0-SNAPSHOT-jar-with-dependencies.jar ${jsonfile} "SparkNonShardedCollection"
echo "Run the Spark application using the dockerised spark server to import ${jsonfile} into SparkShardedCollection"
docker run -v $(pwd)/sampledata:/sampledata  -v $(pwd)/target:/target -it --rm --network mongo_network  spark3.0.1-scala2.12-hadoop3.2.1:latest spark-submit --deploy-mode client --class org.example.App /target/simplespark-1.0-SNAPSHOT-jar-with-dependencies.jar ${jsonfile} "SparkShardedCollection"