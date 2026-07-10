let () =
  Lwt_main.run
    (let open Lwt_result.Syntax in
     let* db = Db.create () in
     let* () = Db.init db in
     let* () = Db.populate db "poems.json" in
     let* results = Db.search_title db ~author:"kipling" "If" in
     match results with
     | [] -> Lwt.return_ok ()
     | poem :: _ ->
       let* epub =
         Epub.generate poem
         |> Lwt_result.map_error (fun msg ->
           Caqti_error.request_failed
             ~uri:(Uri.of_string "epub:")
             ~query:"generate"
             (Caqti_error.Msg msg))
       in
       let* () =
         Lwt_result.ok
           Lwt_io.(with_file ~mode:output "poem.epub" (fun ch -> write ch epub))
       in
       Printf.printf "saved poem.epub (%d bytes)\n" (String.length epub);
       Lwt.return_ok ())
  |> function
  | Ok () -> ()
  | Error err -> failwith (Caqti_error.show err)
;;
