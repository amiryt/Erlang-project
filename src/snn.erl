%%%-------------------------------------------------------------------
%%% @author kyan
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 25. Sep 2020 21:26
%%%-------------------------------------------------------------------
-module(snn).
-author("kyan").

%% API
-export([init/0,start/0]).


init()->

  Pid = spawn(snn, start,[]),
  register(snn,Pid),
  %layer:start(),todo : need to return it!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  Pid
  .

start()->


  snnHandler()

  .


snnHandler()->

  receive
    {monitor,exit}->  ok;%%io:fwrite("recieved exit message  I snn ~n", []);

    {test,InData}->
     %% io:fwrite("data recieved succesfully and need to test it ........~n", []),
      [H|T]=InData,
       %io:format("INPUT DATA IS:::::: ~p ~n",[H]),
     %% io:format("INPUT H  IS:::::: ~p~n",[is_list(H)]),
      [H1|T1]=H,
      %%io:format("INPUT H1 IS:::::: ~p ~n",[is_integer(H1)]),
     % layer:active_input_layer(InData),%% INDATtaa is list of lists todo : need to return it!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      %Result=[1,4,9,16],%% todo : snn network testt imagee
      %spawn(server,graphDraw,[server,'serverNode@127.0.0.1',Result]),
      spawn(server,graphDraw,[server,'serverNode@127.0.0.1',1,1]),%todo : need to remove it!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      %%io:fwrite("sending the result to the server ........~n", []),
      snnHandler()
      ;

    _->io:fwrite("wrong message recieved ........~n", [])

    end






.

