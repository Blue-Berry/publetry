let () =
  Lwt_main.run
    (let open Lwt_result.Syntax in
     let* epub =
       Epub.generate
         { Db.author = "Robert Herrick"
         ; title = "Harvest Home"
         ; text = "Come, sons of summer, by whose toil\nWe are the lords of wine and oil;"
         }
     in
     let path = Filename.temp_file "publetry" ".epub" in
     let* () =
       Lwt_result.ok Lwt_io.(with_file ~mode:output path (fun ch -> write ch epub))
     in
     Printf.printf "wrote %s (%d bytes)\n" path (String.length epub);
     assert (String.length epub > 0);
     assert (String.sub epub 0 2 = "PK");
     Lwt.return_ok ())
  |> function
  | Ok () -> ()
  | Error msg -> failwith msg
;;
