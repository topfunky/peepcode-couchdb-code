function(doc) {
  if (doc.type == "Note" && doc.tags) {
    doc.tags.map(function(tag) {
      emit(tag, doc);
    });
  }
}