package org.example

import org.apache.spark.sql.{DataFrame, Dataset, Row, SparkSession}
import com.mongodb.spark.MongoSpark
import com.mongodb.spark.config.{ReadConfig, WriteConfig}
import java.net.URLEncoder

import org.codehaus.jettison.json.{JSONArray, JSONObject}
import org.bson.Document

/**
 * @author ${user.name}
 */
object App {

  def main(args: Array[String]): Unit = {
    val spark: SparkSession = SparkSession
      .builder()
      .master("local[*]")
      .appName("ETLJob")
      .getOrCreate()
    println("create dataframe")
    val simpleDf:DataFrame = spark.read.text("/sampledata/simpledata.json")
    simpleDf.show
    dataFrameToMongodb("mongos1", "testDb", null, "NonShardedCollection", null, null, null, true, true, simpleDf, spark, true, "value", null, null, false)

    val complexDf:DataFrame = spark.read.text("/sampledata/complexdata.json")
    complexDf.show

    dataFrameToMongodb("mongos1", "testDb", null, "NonShardedCollection", null, null, null, true, true, complexDf, spark, true, "value", null, null, false)
  }

  def dataFrameToMongodb(cluster: String, database: String, authenticationDatabase: String, collection: String, login: String, password: String, replicaset: String, replaceDocuments: Boolean, ordered: Boolean, df: org.apache.spark.sql.DataFrame, sparkSession: org.apache.spark.sql.SparkSession, documentfromjsonfield: Boolean, jsonfield: String, addlSparkOptions: JSONObject, maxBatchSize: String, authenticationEnabled: Boolean): Unit = {

    var uri: String = null
    var vaultLogin: String = null
    var vaultPassword: String = null
    //if password isn't set, attempt to get from security.Vault
    if (authenticationEnabled) {
      vaultPassword = password
      vaultLogin = login
    }
    uri = buildMongoURI(vaultLogin, vaultPassword, cluster, replicaset, authenticationDatabase, database, collection, authenticationEnabled)

    var sparkOptions = Map("uri" -> uri, "replaceDocument" -> replaceDocuments.toString, "ordered" -> ordered.toString)

    if (maxBatchSize != null)
      sparkOptions = sparkOptions ++ Map("maxBatchSize" -> maxBatchSize)

    if (addlSparkOptions != null) {
      sparkOptions = sparkOptions ++ jsonObjectPropertiesToMap(addlSparkOptions)
    }
    println(sparkOptions)
    val writeConfig = WriteConfig(sparkOptions)
    if (documentfromjsonfield) {

      import com.mongodb.spark._
      import sparkSession.implicits._
      val rdd = df.select(jsonfield).map(r => r.getString(0)).rdd
      rdd.map(Document.parse).saveToMongoDB(writeConfig)
    }
    else {
      MongoSpark.save(df, writeConfig)
    }
  }

  def buildMongoURI(login: String, password: String, cluster: String, replicaSet: String, autheticationDatabase: String, database: String, collection: String, authenticationEnabled: Boolean): String = {
    if (authenticationEnabled) {
      "mongodb://" + URLEncoder.encode(login, "UTF-8") + ":" + URLEncoder.encode(password, "UTF-8") + "@" + cluster + ":27017/" + database + "." + collection + "?authSource=" + (if (autheticationDatabase != "") autheticationDatabase else "admin") + (if (replicaSet == null) "" else "&replicaSet=" + replicaSet)
    } else {
      "mongodb://" + cluster + ":27017/" + database + "." + collection + (if (replicaSet == null) "" else "&replicaSet=" + replicaSet)
    }
  }

  def jsonObjectPropertiesToMap(jsonObject: JSONObject): Map[String, String] = {
    var returnMap = Map.empty[String, String]
    var keys = jsonObject.keys()
    while (keys.hasNext()) {
      val key = keys.next().toString()
      val value = jsonObject.getString(key)
      returnMap = returnMap ++ Map(key -> value)
    }
    returnMap
  }
}
