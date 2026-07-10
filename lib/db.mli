type poem =
  { author : string
  ; title : string
  ; text : string
  }

(** A handle to the SQLite database pool. *)
type t

(** Open a SQLite database at the given URI, e.g. ["sqlite3:./publetry.db"]. *)
val connect : string -> (t, Caqti_error.t) result Lwt.t

(** Open the hard-coded SQLite database at [sqlite3:./publetry.db]. *)
val create : unit -> (t, Caqti_error.t) result Lwt.t

(** Close the database pool and release its connections. *)
val close : t -> unit Lwt.t

(** Create the [poems] table and the FTS5 index. Safe to call on an already
    initialised database. *)
val init : t -> (unit, Caqti_error.t) result Lwt.t

(** Store a new poem. *)
val add : t -> poem -> (unit, Caqti_error.t) result Lwt.t

(** Full-text search over author and title. Results are ordered by FTS5 rank. *)
val search : t -> string -> (poem list, Caqti_error.t) result Lwt.t

(** Full-text search over title only. If [~author] is supplied, results are
    further restricted to that author. Results are ordered by FTS5 rank. *)
val search_title
  :  ?author:string
  -> t
  -> string
  -> (poem list, Caqti_error.t) result Lwt.t

(** Full-text search over author only. Results are ordered by FTS5 rank. *)
val search_author : t -> string -> (poem list, Caqti_error.t) result Lwt.t

(** Full-text search over title, returning matching title strings (without
    duplicates). *)
val search_titles : t -> string -> (string list, Caqti_error.t) result Lwt.t

(** Full-text search over author, returning the matching author names (without
    duplicates) rather than full poems. *)
val search_authors : t -> string -> (string list, Caqti_error.t) result Lwt.t

(** Look up a poem by exact author and title (case-insensitive). *)
val find : t -> author:string -> title:string -> (poem option, Caqti_error.t) result Lwt.t

(** Return all poems by a given author (case-insensitive), ordered by title. *)
val find_by_author : t -> string -> (poem list, Caqti_error.t) result Lwt.t

(** Return the number of poems in the database. *)
val count : t -> (int, Caqti_error.t) result Lwt.t

(** Read a JSON array of poems from [path] and insert them into the database.
    Expects objects with ["Author"], ["Title"] and ["text"] string fields. *)
val populate : t -> string -> (unit, Caqti_error.t) result Lwt.t
