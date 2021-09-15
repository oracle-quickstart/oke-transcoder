resource "oci_streaming_stream" "stream" {
    compartment_id = var.compartment_ocid
    name = var.stream_name
    partitions = var.stream_partitions
    retention_in_hours = var.stream_retention_in_hours
}
