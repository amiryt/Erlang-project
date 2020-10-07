%%%-------------------------------------------------------------------
%%% @author kyan
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 05. Oct 2020 16:45
%%%-------------------------------------------------------------------
-module(resmonitor).
-author("kyan").

%% API
-export([init/0,start/5]).


init() ->
  Pid = spawn(resmonitor, start,[1,1,1,1,1]),%% at first there is no pids default is ones
  register(resmonitor,Pid),
  Pid

.




start(Server,Gui,Snn,Graph,MainMonitor)->

%%
%%  put(server,Server),
%%  put(gui,Gui),
%%  put(snn,Snn),
%%  put(graph,Graph),
%%  put(mainMonitor,MainMonitor),
  flush(),
  io:fwrite("reciveing messages ~n", []),
  receive
    {'DOWN', _, process, MainMonitor, Res}-> io:fwrite("I (resMonitor) My monitor ~p died (~p)~n", [MainMonitor, Res]),
      %NewMonitor=restartMainMonitor(Server,Gui,Snn,Graph),
      ReferenceServer = erlang:monitor(process, Server),
      ReferenceGui = erlang:monitor(process, Gui),
      ReferenceSnn = erlang:monitor(process, Snn),
      ReferenceGraph = erlang:monitor(process, Graph),
      monitorloop(Server,Gui,Snn,Graph);%% todo: im the monitor now
    {monitor,NewServer,NewGui,NewSnn,NewGraph}->
      NewMainMonitor=rpc:call('monitorNode@127.0.0.1',erlang,whereis,[monitor]),
      io:fwrite("recived message from main monitor ~p ~n", [NewMainMonitor]),

      MainMonitorref=erlang:monitor(process, NewMainMonitor),
      start(NewServer,NewGui,NewSnn,NewGraph,NewMainMonitor);
    Msg->io:fwrite("recived message from ??? ~p ~n", [Msg])

  end

  .


flush() ->
  receive
    _ -> flush()
  after
    0 -> ok
  end.





start() ->


  flush(),%% todo : what if two computer is dead!
  timer:sleep(2000),

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


  case whereis(resmonitor) of
    undefined->register(resmonitor,self());
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







  io:fwrite("Server is : ~p~n", [Server]),
  io:fwrite("Gui is : ~p~n", [Gui]),
  io:fwrite("Snn is : ~p~n", [Snn]),
  io:fwrite("Graph is : ~p~n", [Graph]),



  _ = erlang:monitor(process, Server),
  _ = erlang:monitor(process, Gui),
  _ = erlang:monitor(process, Snn),
  _ = erlang:monitor(process, Graph),

  monitorloop(Server,Gui,Snn,Graph).
monitorloop(Server,Gui,Snn,Graph)->

  flush(),

  io:format("I resmonitor waiting in the loop ~n", []),
  receive
    {gui,terminate}->
      io:format(" resmonitor: terminating the application ~n", []);



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






    {'DOWN', _, process, Server, Res}-> io:format("I (res monitor) My server ~p died (~p)~n", [Server, Res]),
      {graph,'graphNode@127.0.0.1'}!{monitor,exit},
      {snn,'snnNode@127.0.0.1'}!{monitor,exit},
      {gui,'guiNode@127.0.0.1'}!{monitor,exit},
      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();

    {'DOWN', _, process, Gui, Res}-> io:format("I (res monitor) My gui ~p died (~p)~n", [Gui, Res]),
      {graph,'graphNode@127.0.0.1'}!{monitor,exit},
      {snn,'snnNode@127.0.0.1'}!{monitor,exit},
      spawn(server,stop,[server,'serverNode@127.0.0.1']),
      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();%% sending stop message to server

    {'DOWN', _, process, Snn, Res}-> io:format("I (res monitor) My Snn ~p died (~p)~n", [Snn, Res]),
      {graph,'graphNode@127.0.0.1'}!{monitor,exit},
      {gui,'guiNode@127.0.0.1'}!{monitor,exit},
      spawn(server,stop,[server,'serverNode@127.0.0.1']),
      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();

    {'DOWN', _, process, Graph, Res}-> io:format("I (res monitor) My Graph ~p died (~p)~n", [Graph, Res]),
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
