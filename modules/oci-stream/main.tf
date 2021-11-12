resource "oci_streaming_stream" "stream" {
    compartment_id = var.compartment_ocid
    name = "${var.stream_name}-${random_string.deploy_id.result}"
    partitions = var.stream_partitions
    retention_in_hours = var.stream_retention_in_hours
}
