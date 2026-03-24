# Apple Reminders Database Schema

The Reminders app stores data in SQLite databases at:
```
~/Library/Group Containers/group.com.apple.reminders/Container_v1/Stores/Data-<UUID>.sqlite
```

Multiple databases may exist (one per account — iCloud, local, work, etc.).

## Why Direct DB Access?

EventKit does not expose the URL/link field that Reminders.app displays. The URL is stored
in the `ZREMCDOBJECT` table as a linked object (entity type 26). This is the only way to
read reminder URLs programmatically.

## Entity Relationship Diagram

```mermaid
erDiagram
    ZREMCDREMINDER {
        int Z_PK PK
        int Z_ENT
        int ZCOMPLETED
        int ZFLAGGED
        int ZPRIORITY
        int ZALLDAY
        int ZLIST FK
        int ZPARENTREMINDER FK
        timestamp ZCOMPLETIONDATE
        timestamp ZCREATIONDATE
        timestamp ZDUEDATE
        timestamp ZLASTMODIFIEDDATE
        timestamp ZSTARTDATE
        varchar ZTITLE
        varchar ZNOTES
        varchar ZTIMEZONE
        varchar ZDACALENDARITEMUNIQUEIDENTIFIER "EventKit calendarItemIdentifier"
        varchar ZEXTERNALIDENTIFIER
        varchar ZICSURL
        blob ZIDENTIFIER
    }

    ZREMCDOBJECT {
        int Z_PK PK
        int Z_ENT "Entity type (26 = link/URL)"
        int ZREMINDER FK "Links to reminder (alarm/trigger)"
        int ZREMINDER1 FK
        int ZREMINDER2 FK "Links to reminder (URL/link objects)"
        int ZREMINDER3 FK "Links to reminder (hashtag)"
        int ZREMINDER4 FK
        int ZREMINDER5 FK
        int ZTYPE
        int ZFILESIZE
        int ZHEIGHT
        int ZWIDTH
        varchar ZURL "The URL (only on Z_ENT = 26)"
        varchar ZHOSTURL
        varchar ZTITLE
        varchar ZFILENAME
        varchar ZADDRESS
        varchar ZNAME
        float ZLATITUDE
        float ZLONGITUDE
        float ZRADIUS
        timestamp ZCREATIONDATE
        blob ZIDENTIFIER
        blob ZMETADATA
    }

    ZREMCDBASELIST {
        int Z_PK PK
        int Z_ENT
        int ZACCOUNT FK
        varchar ZNAME "List name (e.g. 'Reminders', 'Shopping')"
        varchar ZEXTERNALIDENTIFIER
        blob ZIDENTIFIER
    }

    ZREMCDBASESECTION {
        int Z_PK PK
        int Z_ENT
        int ZLIST FK
        varchar ZNAME "Section name"
        blob ZIDENTIFIER
    }

    ZREMCDHASHTAGLABEL {
        int Z_PK PK
        varchar ZNAME "Tag name"
    }

    ZREMCDSAVEDATTACHMENT {
        int Z_PK PK
        int ZOWNER FK
        int ZFILESIZE
        int ZHEIGHT
        int ZWIDTH
        varchar ZFILENAME
        varchar ZUTI
    }

    ZREMCDREMINDER ||--o{ ZREMCDOBJECT : "has linked objects"
    ZREMCDBASELIST ||--o{ ZREMCDREMINDER : "contains"
    ZREMCDBASELIST ||--o{ ZREMCDBASESECTION : "has sections"
    ZREMCDREMINDER ||--o{ ZREMCDSAVEDATTACHMENT : "has attachments"
    ZREMCDHASHTAGLABEL ||--o{ ZREMCDOBJECT : "tagged via"
```

## Key Entity Types (Z_ENT in ZREMCDOBJECT)

| Z_ENT | Type | Count (typical) | Description |
|-------|------|-----------------|-------------|
| 15 | Alarm/Trigger | ~654 | Due date alerts linked via ZREMINDER |
| 17 | Account/List metadata | ~730 | List and account configuration |
| 26 | **URL/Link** | ~1053 | **Rich links — the URL field Reminders.app shows** |
| 29 | Recurrence rule | ~633 | Repeat patterns |
| 30 | Participant/Share | ~2011 | Sharing metadata |
| 32 | Hashtag/Tag | ~292 | Tag associations linked via ZREMINDER3 |

## Querying a Reminder's URL

Join `ZREMCDOBJECT` to `ZREMCDREMINDER` via `ZREMINDER2` where `Z_ENT = 26`:

```sql
SELECT o.ZURL
FROM ZREMCDOBJECT o
JOIN ZREMCDREMINDER r ON o.ZREMINDER2 = r.Z_PK
WHERE r.ZDACALENDARITEMUNIQUEIDENTIFIER = '<EventKit-calendarItemIdentifier>'
  AND o.Z_ENT = 26;
```

## Linking EventKit to SQLite

The `ZDACALENDARITEMUNIQUEIDENTIFIER` column in `ZREMCDREMINDER` matches
EventKit's `EKReminder.calendarItemIdentifier`. This is the bridge between
the two data sources.
