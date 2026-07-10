let yaml_string s = "\"" ^ String.escaped s ^ "\""

let markdown_of_poem { Db.author; title; text } =
  Printf.sprintf
    "---\ntitle: %s\nauthor: %s\n---\n\n%s"
    (yaml_string title)
    (yaml_string author)
    text
;;

let command = "pandoc", [| "pandoc"; "-f"; "markdown"; "-t"; "epub3"; "-o"; "-" |]

let generate poem =
  let markdown = markdown_of_poem poem in
  Lwt.catch
    (fun () ->
       Lwt_process.with_process_full command (fun process ->
         let open Lwt.Syntax in
         let* () = Lwt_io.write process#stdin markdown in
         let* () = Lwt_io.close process#stdin in
         let* output = Lwt_io.read process#stdout in
         let* stderr = Lwt_io.read process#stderr in
         let* status = process#close in
         match status with
         | Unix.WEXITED 0 -> Lwt.return_ok output
         | Unix.WEXITED code ->
           Lwt.return_error (Printf.sprintf "pandoc exited with code %d: %s" code stderr)
         | Unix.WSIGNALED s ->
           Lwt.return_error (Printf.sprintf "pandoc killed by signal %d" s)
         | Unix.WSTOPPED s ->
           Lwt.return_error (Printf.sprintf "pandoc stopped by signal %d" s)))
    (function
      | Unix.Unix_error (err, fn, arg) ->
        Lwt.return_error
          (Printf.sprintf
             "could not run pandoc: %s (%s %s)"
             (Unix.error_message err)
             fn
             arg)
      | exn -> Lwt.reraise exn)
;;
