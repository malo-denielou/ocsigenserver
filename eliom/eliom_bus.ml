(* Ocsigen
 * http://www.ocsigen.org
 * Copyright (C) 2010
 * Raphaël Proust
 * Laboratoire PPS - CNRS Université Paris Diderot
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *)

type 'a t = {
  stream  : 'a Lwt_stream.t;
  write   : ('a -> unit);
  service : (unit,
             'a,
             [ `Nonattached of [ `Post ] Eliom_services.na_s ],
             [ `WithoutSuffix ],
             unit,
             [ `One of 'a Eliom_parameters.caml ]
               Eliom_parameters.param_name,
             [ `Registrable ],
             Eliom_output.Action.return
  ) Eliom_services.service;
}

let create ?scope ?name typ =
  (*The stream*)
  let (stream, push) = Lwt_stream.create () in
  let push x = push (Some x) in

  (*The service*)
  let post_params =
    (Eliom_parameters.caml "bus_write" typ
       : ('a, 'aa, 'aaa) Eliom_parameters.params_type)
  in
  let distant_write = Eliom_services.post_coservice' ?name ~post_params () in
  Eliom_output.Action.register
    ?scope
    ~options:`NoReload
    ~service:distant_write
    (fun () x -> push x ; Lwt.return ());

  (*The bus*)
  let bus =
    { stream  = stream;
      write   = push;
      service = distant_write; }
  in

  bus

let stream bus = bus.stream

let write bus x = bus.write x

let wrap (bus: 'a t)
  : (  ('a Eliom_common_comet.chan_id)
     * (unit,
        'a,
        [ `Nonattached of [ `Post ] Eliom_services.na_s ],
        [ `WithoutSuffix ],
        unit,
        [ `One of 'a Eliom_parameters.caml ] Eliom_parameters.param_name,
        [ `Registrable ],
        Eliom_output.Action.return
       ) Eliom_services.service
    ) Eliom_client_types.data_key
  =
  let chan = Eliom_comet.Channels.create (Lwt_stream.clone bus.stream) in
  Eliommod_cli.wrap (Eliom_comet.Channels.get_id chan, 
                     Eliom_services.pre_wrap bus.service)
  
