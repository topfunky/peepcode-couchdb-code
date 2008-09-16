function(doc) {
  if (doc.type == "Note") {
    emit(Date.parse(doc.updated_at.data), doc);
  }
}