#!/usr/bin/python

"""
This example code shows how to source COS bucket for Spark job.
"""

import sys
import os
import argparse
from pyspark import SparkConf
from pyspark.sql import SparkSession


def main(args):
    # The appName will be sth like '///spark/data/example_pyspark_job.py'
    app_name = os.getcwd() + '/' + sys.argv[0]

    # Create SparkSession
    job_conf = SparkConf() \
        .setAppName(app_name).set("spark.executor.memory", "4g") \
        .set("spark.executor.cores", "2") \
        .set("fs.stocator.scheme.list", "cos") \
        .set("fs.cos.impl", "com.ibm.stocator.fs.ObjectStoreFileSystem") \
        .set("fs.stocator.cos.impl", "com.ibm.stocator.fs.cos.COSAPIClient") \
        .set("fs.stocator.cos.scheme", "cos") \
        .set("fs.cos.{}.iam.api.key".format(args.service_name), args.api_key) \
        .set("fs.cos.{}.endpoint".format(args.service_name), args.endpoint) \
        #.config("fs.cos.myCos.iam.service.id", args.resource_instance_id) #optional in this example

    spark = SparkSession \
        .builder \
        .config(conf=job_conf) \
        .getOrCreate()

    input_file_path = "cos://{}.{}/{}/".format(args.input_bucket, args.service_name, args.input_path)
    print('file_path', input_file_path)
    df = spark.read.parquet(input_file_path)
    print("========================================================")
    print("SHOW INPUT")
    print("========================================================")
    print(df.show())

    output_file_path = "cos://{}.{}/{}/".format(args.output_bucket, args.service_name, args.output_path)
    print('file_path', output_file_path)
    df.select(df.columns[:2]).limit(5).write.mode('overwrite').parquet(output_file_path)
    df_out = spark.read.parquet(output_file_path)
    print("========================================================")
    print("SHOW OUTPUT")
    print("========================================================")
    print(df_out.show())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-k', dest='api_key', required=True, help='API key to access the COS bucket')
    parser.add_argument('-e', dest='endpoint', required=True, help='The endpoint for the COS bucket')
    parser.add_argument('-i', dest='input_bucket', required=True, help='Name of the input COS bucket')
    parser.add_argument('-o', dest='output_bucket', required=True, help='Name of the output COS bucket')
    parser.add_argument('--input-path', dest='input_path', required=True,
                        help='Path under the input bucket to the input file(s)')
    parser.add_argument('--output-path', dest='output_path', required=False, default=None,
                        help='Output path under the output bucket to the output file(s)')
    parser.add_argument('-r', dest='resource_instance_id', required=False, default=None,
                        help='Resource instance id for the COS bucket')
    parser.add_argument('-s', dest='service_name', required=True,
                        help='Service name required by IBM Stocator library, this could be arbitrary string, for example, "myCos"')
    args = parser.parse_args()

    main(args)
