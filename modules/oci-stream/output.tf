output "stream_id" {
    value = oci_streaming_stream.stream.id
}

output "messages_endpoint" {
    value = oci_streaming_stream.stream.messages_endpoint
}
