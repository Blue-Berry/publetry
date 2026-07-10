(lang dune 3.20)

(name publetry)
(version de1adcc-dirty)

(generate_opam_files true)

(source
 (github username/reponame))

(authors "Author Name <author@example.com>")

(maintainers "Maintainer Name <maintainer@example.com>")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name publetry)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends
  ocaml
  caqti
  caqti-lwt
  caqti-driver-sqlite3
  dream
  yojson
  ppx_deriving_yojson)
 (tags
  ("add topics" "to describe" your project)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
