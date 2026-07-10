(** [generate poem] runs pandoc on a Markdown/YAML document built from the poem
    and returns the raw EPUB3 bytes. On error it returns a human-readable
    message. Pandoc is invoked through stdin/stdout so no temporary files are
    created. *)
val generate : Db.poem -> (string, string) result Lwt.t
