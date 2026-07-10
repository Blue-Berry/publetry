let copy_prebuilt_db () =
  let exe_dir = Filename.dirname Sys.executable_name in
  let build_dir = Filename.dirname exe_dir in
  let prebuilt = Filename.concat build_dir "publetry.db" in
  if Sys.file_exists prebuilt && not (Sys.file_exists "publetry.db")
  then (
    Printf.printf "Copying prebuilt database from %s\n%!" prebuilt;
    Lwt_main.run
      (let open Lwt.Syntax in
       let* data = Lwt_io.(with_file ~mode:input prebuilt (fun ch -> read ch)) in
       Lwt_io.(with_file ~mode:output "publetry.db" (fun ch -> write ch data))))
;;

let () =
  copy_prebuilt_db ();
  let db =
    Lwt_main.run
      (let open Lwt_result.Syntax in
       let* db = Db.create () in
       let* () = Db.init db in
       let* n = Db.count db in
       let* () = if n = 0 then Db.populate db "poems.json" else Lwt.return_ok () in
       Lwt.return_ok db)
    |> function
    | Ok db -> db
    | Error err -> failwith (Caqti_error.show err)
  in
  print_endline "Starting Publetry on http://0.0.0.0:8080";
  Web.run db
;;
