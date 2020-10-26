#!/bin/bash
echo "spin up the mongodb clusters"
docker-compose up -d
# wait a bit
sleep 5
echo "configure our config servers replica set"
docker-compose exec mongocfg1 bash -c "echo 'rs.initiate({_id: \"mongors1conf\",configsvr: true, members: [{ _id : 0, host : \"mongocfg1:27019\" },{ _id : 1, host : \"mongocfg2:27019\" }, { _id : 2, host : \"mongocfg3:27019\" }]})' | mongo --port 27019"
echo "build our shard replica sets"
docker-compose exec mongors1n1 bash -c "echo 'rs.initiate({_id : \"mongors1\", members: [{ _id : 0, host : \"mongors1n1:27018\" },{ _id : 1, host : \"mongors1n2:27018\" },{ _id : 2, host : \"mongors1n3:27018\" }]})' | mongo --port 27018"
docker-compose exec mongors2n1 bash -c "echo 'rs.initiate({_id : \"mongors2\", members: [{ _id : 0, host : \"mongors2n1:27018\" },{ _id : 1, host : \"mongors2n2:27018\" },{ _id : 2, host : \"mongors2n3:27018\" }]})' | mongo --port 27018"
# wait a bit
sleep 15
echo "introduce our shards to the routers"
docker-compose exec mongos1 bash -c "echo 'sh.addShard(\"mongors1/mongors1n1:27018,mongors1n2:27018,mongors1n3:27018\")' | mongo"
docker-compose exec mongos2 bash -c "echo 'sh.addShard(\"mongors1/mongors1n1:27018,mongors1n2:27018,mongors1n3:27018\")' | mongo"
docker-compose exec mongos1 bash -c "echo 'sh.addShard(\"mongors2/mongors2n1:27018,mongors2n2:27018,mongors2n3:27018\")' | mongo"
docker-compose exec mongos2 bash -c "echo 'sh.addShard(\"mongors2/mongors2n1:27018,mongors2n2:27018,mongors2n3:27018\")' | mongo"
echo "create a database named testDb"
docker-compose exec mongos1 bash -c "echo 'use testDb' | mongo"
echo "enable sharding on our newly created database"
docker-compose exec mongos1 bash -c "echo 'sh.enableSharding(\"testDb\")' | mongo"
echo "create a non-sharded collection on our sharded database"
docker-compose exec mongos1 bash -c "echo -e 'use testDb\ndb.createCollection(\"NonShardedCollection\")' | mongo"
echo "create a sharded collection on our sharded database"
docker-compose exec mongos1 bash -c "echo -e 'use testDb\ndb.createCollection(\"ShardedCollection\")' | mongo"
echo "shard our collection on a field named shardingField"
docker-compose exec mongos1 bash -c "echo 'sh.shardCollection(\"testDb.ShardedCollection\", {\"shardingField\" : \"hashed\"})' | mongo"
# docker-compose exec mongos1 bash -c "echo -e 'use testDb\ndb.ShardedCollection.createIndex( { \"_id\": 1, \"shardingField\": 1 }, { unique: true } )' | mongo"
# docker-compose exec mongos1 bash -c "echo -e 'use testDb\ndb.testCollection.getShardDistribution()' | mongo"
# docker-compose exec mongos1 bash -c "echo -e 'use testDb\ndb.testCollection.drop()' | mongo"