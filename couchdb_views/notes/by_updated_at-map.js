function(doc) {
  if (doc.type == "Note") {
    emit(doc.updated_at.data, doc);
  }
}