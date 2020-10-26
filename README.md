# mongotestsparkreplacedocument
This repo tests 
1. mongoimport's merge feature against simple and complex documents
1. the mongo spark connector's replaceDocument feature against a non-sharded collection

## Steps
From the root of the repo, run
```shell script
chmod +x install.sh
./install.sh complexdata.json
```
This
1. spins up a sharded mongodb cluster with 4 collections
    1. non-sharded collections NonShardedCollection, SparkNonShardedCollection
    1. sharded collections ShardedCollection, SparkShardedCollection with shard field as `shardedField`
1. writes [complexdata.json](sampledata/complexdata.json) (each line is a document) using 
    1. mongoimport
    1. mongodb spark connector

### Cleanup
Run 
```shell script
docker-compose -f ./mongodb_server/docker-compose.yml down -v
```

> Use `sudo chown -R $(whoami):$(whoami) .` to get access to folders/files created by docker