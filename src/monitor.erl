%%%-------------------------------------------------------------------
%%% @author kyan
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 01. Oct 2020 13:02
%%%-------------------------------------------------------------------
-module(monitor).
-author("kyan").

%% API
-export([start/0,restart/4,restart1/4]).

restart(Server,Gui,Snn,Graph)->
  Pid = spawn(monitor, restart1,[Server,Gui,Snn,Graph]),
  register(monitor,Pid),
  Pid
  .
restart1(Server,Gui,Snn,Graph) ->
  ResMonitor=rpc:call('resmonitorNode@127.0.0.1',erlang,whereis,[resmonitor]),
  io:format("restarting the monitor ~n", []),
  ReferenceServer = erlang:monitor(process, Server),
  ReferenceGui = erlang:monitor(process, Gui),
  ReferenceSnn = erlang:monitor(process, Snn),
  ReferenceGraph = erlang:monitor(process, Graph),
  ReferenceResMonitor=erlang:monitor(process, ResMonitor),
  restartloop(Server,Gui,Snn,Graph,ResMonitor).


restartloop(Server,Gui,Snn,Graph,ResMonitor)->


  flush(),%% todo : what if two computer is dead!

  io:format("I (monitor waiting in the loop ~n", []),
  receive
    {gui,terminate}->
      io:format(" monitor: terminating the application ~n", []);




    {'DOWN', _, process, ResMonitor, _}-> io:format("I (monitor) My resMobitor ~p died (~p)~n", [ResMonitor, normal]),
      restartloop(Server,Gui,Snn,Graph,restartResMonitor(Server,Gui,Snn,Graph));%% no need for restart all the application






    {'DOWN', _, process, Server, _}-> io:format("I (monitor) My server ~p died (~p)~n", [Server, normal]),
      {graph,'graphNode@127.0.0.1'}!{monitor,exit},
      {snn,'snnNode@127.0.0.1'}!{monitor,exit},
      {gui,'guiNode@127.0.0.1'}!{monitor,exit},
      io:format("restarting the application ~n", []),
      start();

    {'DOWN', _, process, Gui, _}-> io:format("I (monitor) My gui ~p died (~p)~n", [Gui, normal]),
      {graph,'graphNode@127.0.0.1'}!{monitor,exit},
      {snn,'snnNode@127.0.0.1'}!{monitor,exit},
      spawn(server,stop,[server,'serverNode@127.0.0.1']),
      io:format("restarting the application ~n", []),
      start();%% sending stop message to server

    {'DOWN', _, process, Snn, _}-> io:format("I (monitor) My Snn ~p died (~p)~n", [Snn, normal]),
      {graph,'graphNode@127.0.0.1'}!{monitor,exit},
      {gui,'guiNode@127.0.0.1'}!{monitor,exit},
      spawn(server,stop,[server,'serverNode@127.0.0.1']),
      io:format("restarting the application ~n", []),
      start();

    {'DOWN', _, process, Graph, _}-> io:format("I (monitor) My Graph ~p died (~p)~n", [Graph, normal]),
      {snn,'snnNode@127.0.0.1'}!{monitor,exit},
      {gui,'guiNode@127.0.0.1'}!{monitor,exit},
      spawn(server,stop,[server,'serverNode@127.0.0.1']),
      io:format("restarting the application ~n", []),
      start();



    Rec->io:format("what the fuck is here:   ~p ~n", [Rec])


  end
  .
start() ->


  flush(),%% todo : what if two computer is dead!
  timer:sleep(2000),

  case rpc:call('resmonitorNode@127.0.0.1', erlang, whereis, [resmonitor]) of
    {badrpc,_}->io:format("you need to create resmonitor node ~n", []),
      start();

    undefined->
      io:format("you need to create resmonitor process ~n", []),
      start();


    _->ok


  end,

  case rpc:call('serverNode@127.0.0.1', erlang, whereis, [server]) of
    {badrpc,_}->io:format("you need to create server node ~n", []),
      start();

    undefined->ok;
%%      io:format("you need to create server process ~n", []),
%%      start();


    _->ok


  end,


  case rpc:call('guiNode@127.0.0.1', erlang, whereis, [gui]) of
    {badrpc,_}->io:format("you need to create gui node ~n", []),
      start();

    undefined->
      ok;
%%      io:format("you need to create gui process ~n", []),
%%      start();


    _->ok


  end,
  case rpc:call('snnNode@127.0.0.1', erlang, whereis, [snn]) of
    {badrpc,_}->io:format("you need to create snn node ~n", []),
      start();

    undefined->
      ok;
%%      io:format("you need to create snn process ~n", []),
%%      start();

    _->ok


  end,
  case rpc:call('graphNode@127.0.0.1', erlang, whereis, [graph]) of
    {badrpc,_}->io:format("you need to create graph node ~n", []),
      start();
    undefined->ok;
%%      io:format("you need to create graph process ~n", []),
%%      start();

    _->ok


  end,


  case whereis(monitor) of
    undefined->register(monitor,self());
    _->ok
  end,





  Server=rpc:call('serverNode@127.0.0.1',server,start,[]),
  Gui=rpc:call('guiNode@127.0.0.1',wxd,init,[]),
  Snn=rpc:call('snnNode@127.0.0.1',snn,init,[]),
  Graph=rpc:call('graphNode@127.0.0.1',graphs,init,[]),
%%  Server=rpc:call('serverNode@127.0.0.1',erlang,whereis,[server]),
%%  Gui=rpc:call('guiNode@127.0.0.1',erlang,whereis,[gui]),
%%  Snn=rpc:call('snnNode@127.0.0.1',erlang,whereis,[snn]),
%%  Graph=rpc:call('graphNode@127.0.0.1',erlang,whereis,[graph]),
%%

  ResMonitor=rpc:call('resmonitorNode@127.0.0.1',erlang,whereis,[resmonitor]),





  {resmonitor,'resmonitorNode@127.0.0.1'}!{monitor,Server,Gui,Snn,Graph},

  io:fwrite("Gui is : ~p~n", [Server]),
  io:fwrite("Gui is : ~p~n", [Gui]),
  io:fwrite("Snn is : ~p~n", [Snn]),
  io:fwrite("Graph is : ~p~n", [Graph]),
  io:fwrite("ResMonitor is : ~p~n", [ResMonitor]),



  ReferenceServer = erlang:monitor(process, Server),
  ReferenceGui = erlang:monitor(process, Gui),
  ReferenceSnn = erlang:monitor(process, Snn),
  ReferenceGraph = erlang:monitor(process, Graph),
  erlang:monitor(process, ResMonitor),

  monitorloop(Server,Gui,Snn,Graph,ResMonitor)
.

monitorloop(Server,Gui,Snn,Graph,ResMonitor)->

  flush(),

  io:format("I (monitor waiting in the loop ~n", []),
  receive
    {gui,terminate}->
      io:format(" monitor: terminating the application ~n", []);



%%      Ret-> io:format("shell recieved    !!!!!!!!:  ~p ~n", [Ret]),
%%             case rpc:call('guiNode@127.0.0.1', erlang, whereis, [gui]) of
%%              {badrpc,_}->io:format("guiNode is died: ~n", []);
%%              undefined->io:format("gui Process is died: ~n", []);
%%              _->io:format("shell !!!! sending exit to gui: ~n", []),
%%                {gui,'guiNode@127.0.0.1'}!{server,exit}
%%            end,
%%            case rpc:call('snnNode@127.0.0.1', erlang, whereis, [snn]) of
%%            {badrpc,_}->io:format("snnNode is died: ~n", []);
%%            undefined->io:format("snn Process is died: ~n", []);
%%              _->
%%                io:format("shell !!!! sending exit to snn: ~n", []),
%%                {snn,'snnNode@127.0.0.1'}!{server,exit}
%%            end,
%%            case rpc:call('graphNode@127.0.0.1', erlang, whereis, [graph]) of
%%            {badrpc,_}->io:format("graphNode is died: ~n", []);
%%            undefined->io:format("graph Process is died: ~n", []);
%%              _->
%%                io:format("shell !!!! sending exit to graph: ~n", []),
%%                {graph,'graphNode@127.0.0.1'}!{server,exit}
%%            ends
%%      ;


  %% terminating the other process

    {'DOWN', _, process, ResMonitor, _}->
     io:format("I (monitor) My resMobitor ~p died (~p)~n", [ResMonitor, normal]),
      NewResMonitor=restartResMonitor(Server,Gui,Snn,Graph),
     monitorloop(Server,Gui,Snn,Graph,NewResMonitor),%% no need for restart
     _=erlang:monitor(process, NewResMonitor);






    {'DOWN', _, process, Server, _}-> io:format("I (monitor) My server ~p died (~p)~n", [Server, normal]),
      {graph,'graphNode@127.0.0.1'}!{monitor,exit},
      {snn,'snnNode@127.0.0.1'}!{monitor,exit},
      {gui,'guiNode@127.0.0.1'}!{monitor,exit},
      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();

    {'DOWN', _, process, Gui, _}-> io:format("I (monitor) My gui ~p died (~p)~n", [Gui, normal]),
      {graph,'graphNode@127.0.0.1'}!{monitor,exit},
      {snn,'snnNode@127.0.0.1'}!{monitor,exit},
      spawn(server,stop,[server,'serverNode@127.0.0.1']),
      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();%% sending stop message to server

    {'DOWN', _, process, Snn, _}-> io:format("I (monitor) My Snn ~p died (~p)~n", [Snn, normal]),
      {graph,'graphNode@127.0.0.1'}!{monitor,exit},
      {gui,'guiNode@127.0.0.1'}!{monitor,exit},
      spawn(server,stop,[server,'serverNode@127.0.0.1']),
      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();

    {'DOWN', _, process, Graph, _}-> io:format("I (monitor) My Graph ~p died (~p)~n", [Graph, normal]),
      {snn,'snnNode@127.0.0.1'}!{monitor,exit},
      {gui,'guiNode@127.0.0.1'}!{monitor,exit},
      spawn(server,stop,[server,'serverNode@127.0.0.1']),
      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();



    Rec->io:format("what the fuck is here:   ~p ~n", [Rec])


  end


  %%io:format("restarting the application ~n", [])



.


restartResMonitor(Server,Gui,Snn,Graph)->
  timer:sleep(1000),

  case rpc:call('resmonitorNode@127.0.0.1', erlang, whereis, [resmonitor]) of
    {badrpc,_}->io:format("you need to create resMonitor node ~n", []),
    restartResMonitor(Server,Gui,Snn,Graph);

    undefined->ResMonitor=rpc:call('resmonitorNode@127.0.0.1',resMonitor,init,[]),%% todo: need to change
      {resmonitor,'resmonitorhNode@127.0.0.1'}!{Server,Gui,Snn,Graph}
    ;


    ResMonitor->ResMonitor


  end

  .


flush() ->
  receive
    _ -> flush()
  after
    0 -> ok
  end.
