type poem =
  { author : string
  ; title : string
  ; text : string
  }

(** A handle to the SQLite database pool. *)
type t

(** Open the hard-coded SQLite database at [sqlite3:./publetry.db]. *)
val create : unit -> (t, Caqti_error.t) result Lwt.t

(** Create the [poems] table and the FTS5 index. Safe to call on an already
    initialised database. *)
val init : t -> (unit, Caqti_error.t) result Lwt.t

(** Store a new poem. *)
val add : t -> poem -> (unit, Caqti_error.t) result Lwt.t

(** Full-text search over author and title. Results are ordered by FTS5 rank. *)
val search : t -> string -> (poem list, Caqti_error.t) result Lwt.t

(** Read a JSON array of poems from [path] and insert them into the database.
    Expects objects with ["Author"], ["Title"] and ["text"] string fields. *)
val populate : t -> string -> (unit, Caqti_error.t) result Lwt.t
