.pragma library
.import QtQuick.LocalStorage 2.0 as Sql

// Persistent storage for voice notes (SQLite via QtQuick.LocalStorage, Qt 5.6).

function getDatabase() {
    var db = Sql.LocalStorage.openDatabaseSync("STTNotes", "1.0",
                                               "Speech-to-text notes", 1000000)
    db.transaction(function(tx) {
        tx.executeSql("CREATE TABLE IF NOT EXISTS notes ("
                      + "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                      + "title TEXT, "
                      + "date TEXT, "
                      + "text TEXT, "
                      + "duration TEXT, "
                      + "audio TEXT, "
                      + "created INTEGER)")
    })
    return db
}

function makePreview(text) {
    var t = text ? text.replace(/\s+/g, " ").trim() : ""
    if (t.length > 100) {
        return t.substring(0, 100) + "..."
    }
    return t
}

// Load all notes (newest first) into the given ListModel.
function loadNotes(model) {
    var db = getDatabase()
    db.readTransaction(function(tx) {
        var rs = tx.executeSql("SELECT id, title, date, text, duration, audio "
                               + "FROM notes ORDER BY created DESC")
        model.clear()
        for (var i = 0; i < rs.rows.length; i++) {
            var row = rs.rows.item(i)
            model.append({
                "noteId": row.id,
                "title": row.title,
                "date": row.date,
                "text": row.text,
                "preview": makePreview(row.text),
                "duration": row.duration,
                "audio": row.audio
            })
        }
    })
}

// Insert a note. Returns the new note id, or -1 on failure.
function addNote(title, date, text, duration, audio) {
    var db = getDatabase()
    var newId = -1
    db.transaction(function(tx) {
        var rs = tx.executeSql("INSERT INTO notes (title, date, text, duration, audio, created) "
                               + "VALUES (?, ?, ?, ?, ?, ?)",
                               [title, date, text, duration, audio, Date.now()])
        newId = parseInt(rs.insertId)
    })
    return newId
}

function deleteNote(noteId) {
    var db = getDatabase()
    db.transaction(function(tx) {
        tx.executeSql("DELETE FROM notes WHERE id = ?", [noteId])
    })
}

function notesCount() {
    var db = getDatabase()
    var count = 0
    db.readTransaction(function(tx) {
        var rs = tx.executeSql("SELECT COUNT(*) AS c FROM notes")
        if (rs.rows.length > 0) {
            count = rs.rows.item(0).c
        }
    })
    return count
}
