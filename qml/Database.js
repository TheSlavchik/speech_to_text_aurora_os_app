.pragma library
.import QtQuick.LocalStorage 2.0 as Sql

// Persistent storage for voice notes (SQLite via QtQuick.LocalStorage, Qt 5.6).

function getDatabase() {
    var db = Sql.LocalStorage.openDatabaseSync("voicenotes", "1.0",
                                               "Speech-to-text notes", 1000000)
    db.transaction(function(tx) {
        tx.executeSql("CREATE TABLE IF NOT EXISTS notes ("
                      + "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                      + "title TEXT, "
                      + "date TEXT, "
                      + "text TEXT, "
                      + "duration TEXT, "
                      + "audio TEXT, "
                      + "tags TEXT DEFAULT '', "
                      + "created INTEGER)")
        // Add file_size column if upgrading from older schema
        try {
            tx.executeSql("ALTER TABLE notes ADD COLUMN file_size INTEGER DEFAULT 0")
        } catch (e) { /* column already exists */ }
        // Add tags column if upgrading from older schema
        try {
            tx.executeSql("ALTER TABLE notes ADD COLUMN tags TEXT DEFAULT ''")
        } catch (e) { /* column already exists */ }
        // Add modified column if upgrading from older schema
        try {
            tx.executeSql("ALTER TABLE notes ADD COLUMN modified INTEGER DEFAULT 0")
        } catch (e) { /* column already exists */ }
        // Create tags table
        tx.executeSql("CREATE TABLE IF NOT EXISTS tags ("
                      + "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                      + "name TEXT UNIQUE, "
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

// Formats bytes into human-readable size (KB or MB).
function formatFileSize(bytes) {
    if (!bytes || bytes === 0) return "0 KB"
    if (bytes >= 1048576) return (bytes / 1048576.0).toFixed(1) + " MB"
    if (bytes >= 1024) return Math.round(bytes / 1024.0) + " KB"
    return bytes + " B"
}

// Convert duration string "MM:SS" to total seconds.
function durationToSeconds(duration) {
    if (!duration) return 0
    var parts = duration.split(":")
    if (parts.length !== 2) return 0
    var min = parseInt(parts[0]) || 0
    var sec = parseInt(parts[1]) || 0
    return min * 60 + sec
}

// Load all notes into the given ListModel.
function loadNotes(model, sortMode, sortDir) {
    var mode = sortMode || "date"
    var dir = sortDir || "desc"
    var order = ""
    var sortInJS = false

    if (mode === "date") {
        order = dir === "asc" ? "ORDER BY created ASC" : "ORDER BY created DESC"
    } else if (mode === "title") {
        order = dir === "asc" ? "ORDER BY title ASC" : "ORDER BY title DESC"
    } else if (mode === "duration") {
        order = "ORDER BY created DESC"
        sortInJS = true
    } else if (mode === "size") {
        order = "ORDER BY created DESC"
        sortInJS = true
    } else if (mode === "modified") {
        order = "ORDER BY created DESC"
        sortInJS = true
    }

    var db = getDatabase()
    db.readTransaction(function(tx) {
        var rs = tx.executeSql("SELECT id, title, date, text, duration, audio, file_size, tags, modified "
                               + "FROM notes " + order)
        var rows = []
        for (var i = 0; i < rs.rows.length; i++) {
            rows.push(rs.rows.item(i))
        }

        if (sortInJS) {
            if (mode === "duration") {
                rows.sort(function(a, b) {
                    var diff = durationToSeconds(a.duration) - durationToSeconds(b.duration)
                    return dir === "asc" ? diff : -diff
                })
            } else if (mode === "size") {
                rows.sort(function(a, b) {
                    var diff = (a.file_size || 0) - (b.file_size || 0)
                    return dir === "asc" ? diff : -diff
                })
            } else if (mode === "modified") {
                rows.sort(function(a, b) {
                    var diff = (a.modified || 0) - (b.modified || 0)
                    return dir === "asc" ? diff : -diff
                })
            }
        }

        model.clear()
        for (var j = 0; j < rows.length; j++) {
            var row = rows[j]
            var parts = (row.tags || "").split("|")
            model.append({
                "noteId": row.id,
                "title": row.title,
                "date": row.date,
                "text": row.text,
                "preview": makePreview(row.text),
                "duration": row.duration,
                "audio": row.audio,
                "fileSize": formatFileSize(row.file_size || 0),
                "tags": row.tags || ""
            })
        }
    })
}

// Insert a note. Returns the new note id, or -1 on failure.
function addNote(title, date, text, duration, audio, fileSizeBytes) {
    var db = getDatabase()
    var newId = -1
    var fs = fileSizeBytes || 0
    db.transaction(function(tx) {
        var rs = tx.executeSql("INSERT INTO notes (title, date, text, duration, audio, file_size, created) "
                               + "VALUES (?, ?, ?, ?, ?, ?, ?)",
                               [title, date, text, duration, audio, fs, Date.now()])
        newId = parseInt(rs.insertId)
    })
    return newId
}

function deleteNote(noteId) {
    var db = getDatabase()
    db.transaction(function(tx) {
        tx.executeSql("DELETE FROM notes WHERE id = ?", [noteId])
    })
    cleanupOrphanedTags()
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

function deleteNotes(ids) {
    if (!ids || ids.length === 0) return 0
    var db = getDatabase()
    var count = 0
    db.transaction(function(tx) {
        var placeholders = ids.map(function() { return "?" }).join(",")
        var r = tx.executeSql("DELETE FROM notes WHERE id IN (" + placeholders + ")", ids)
        count = r.rowsAffected
    })
    cleanupOrphanedTags()
    return count
}

function updateNoteTitle(id, newTitle) {
    var db = getDatabase()
    var ok = false
    db.transaction(function(tx) {
        var r = tx.executeSql("UPDATE notes SET title = ?, modified = ? WHERE id = ?", [newTitle, Date.now(), id])
        ok = r.rowsAffected > 0
    })
    return ok
}

// Tag functions

function cleanupOrphanedTags() {
    var db = getDatabase()
    db.transaction(function(tx) {
        tx.executeSql("DELETE FROM tags")
        var rsAll = tx.executeSql("SELECT tags FROM notes WHERE tags IS NOT NULL AND tags <> ''")
        var allTagsSet = {}
        for (var k = 0; k < rsAll.rows.length; k++) {
            var rowTags = rsAll.rows.item(k).tags
            var arr = rowTags.split("|")
            for (var a = 0; a < arr.length; a++) {
                var tag = arr[a].trim()
                if (tag.length > 0) {
                    allTagsSet[tag] = true
                }
            }
        }
        var uniqueTags = Object.keys(allTagsSet)
        for (var u = 0; u < uniqueTags.length; u++) {
            tx.executeSql("INSERT OR IGNORE INTO tags (name, created) VALUES (?, ?)", [uniqueTags[u], Date.now()])
        }
    })
}

function updateNoteTags(noteId, tags) {
    var db = getDatabase()
    // Remove duplicates
    var seen = {}
    var unique = []
    for (var i = 0; i < tags.length; i++) {
        var t = tags[i].trim()
        if (t.length > 0 && !seen[t]) {
            seen[t] = true
            unique.push(t)
        }
    }
    var tagStr = unique.join("|")
    db.transaction(function(tx) {
        tx.executeSql("UPDATE notes SET tags = ? WHERE id = ?", [tagStr, noteId])
        // Insert new tags
        for (var i = 0; i < tags.length; i++) {
            var t = tags[i].trim()
            if (t.length > 0) {
                tx.executeSql("INSERT OR IGNORE INTO tags (name, created) VALUES (?, ?)", [t, Date.now()])
            }
        }
        // Rebuild tags table from current notes to remove orphaned tags
        tx.executeSql("DELETE FROM tags")
        var rsAll = tx.executeSql("SELECT tags FROM notes WHERE tags IS NOT NULL AND tags <> ''")
        var allTagsSet = {}
        for (var k = 0; k < rsAll.rows.length; k++) {
            var rowTags = rsAll.rows.item(k).tags
            var arr = rowTags.split("|")
            for (var a = 0; a < arr.length; a++) {
                var tag = arr[a].trim()
                if (tag.length > 0) {
                    allTagsSet[tag] = true
                }
            }
        }
        var uniqueTags = Object.keys(allTagsSet)
        for (var u = 0; u < uniqueTags.length; u++) {
            tx.executeSql("INSERT OR IGNORE INTO tags (name, created) VALUES (?, ?)", [uniqueTags[u], Date.now()])
        }
    })
}

function updateNoteText(noteId, newText) {
    var db = getDatabase()
    var ok = false
    db.transaction(function(tx) {
        var r = tx.executeSql("UPDATE notes SET text = ?, modified = ? WHERE id = ?", [newText, Date.now(), noteId])
        ok = r.rowsAffected > 0
    })
    return ok
}

function getNoteDetails(noteId, callback) {
    var db = getDatabase()
    db.transaction(function(tx) {
        var result = {}
        var rs = tx.executeSql("SELECT * FROM notes WHERE id = ?", [noteId])
        if (rs.rows.length > 0) {
            var row = rs.rows.item(0)
            var audioPath = row.audio || ""
            var fileName = audioPath.split("/").pop() || ""
            result.fileName = fileName
            result.filePath = audioPath
            result.fileSize = formatFileSize(row.file_size || 0)
            result.duration = row.duration || ""
            result.type = fileName.indexOf(".wav") >= 0 ? "WAV" :
                         (fileName.indexOf(".mp3") >= 0 ? "MP3" : "Аудио")
            result.created = row.date || ""
            var mod = row.modified || 0
            result.modified = mod > 0 ? new Date(mod).toLocaleString() : ""
            result.tags = (row.tags || "").replace(/\|/g, ", ")
        }
        if (callback) callback(result)
    })
}

function getAllTags() {
    var db = getDatabase()
    var tagList = []
    db.readTransaction(function(tx) {
        var rs = tx.executeSql("SELECT name FROM tags ORDER BY name ASC")
        for (var i = 0; i < rs.rows.length; i++) {
            tagList.push(rs.rows.item(i).name)
        }
    })
    return tagList
}
