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
-export([init/0, start/0, createdefmonitor/7, getActive/0]).



init() ->
  spawn(monitor, start, [])
.


start() ->


  flush(),%% todo : what if two computer is dead!
  timer:sleep(2000),

  %% checking if the node is on
  case rpc:call('resmonitorNode@127.0.0.1', erlang, whereis, [resmonitor]) of
    {badrpc, _} -> io:format("you need to create resmonitor node ~n", []),
      start();

    undefined ->
      io:format("you need to create resmonitor process ~n", []),
      start();


    _ -> ok


  end,
  %% checking if the node is on
  case rpc:call('serverNode@127.0.0.1', erlang, whereis, [server]) of
    {badrpc, _} -> io:format("you need to create server node ~n", []),
      start();

    undefined -> ok;



    _ -> ok


  end,

  %% checking if the node is on
  case rpc:call('graphicsNode@127.0.0.1', erlang, whereis, [gui]) of
    {badrpc, _} -> io:format("you need to create graphics node ~n", []),
      start();

    undefined ->
      ok;


    _ -> ok


  end,
  %% checking if the node is on
  case rpc:call('snnNode@127.0.0.1', erlang, whereis, [snn]) of
    {badrpc, _} -> io:format("you need to create snn node ~n", []),
      start();

    undefined ->
      ok;

    _ -> ok


  end,
  %% checking if the node is on
  case rpc:call('outlayerNode@127.0.0.1', erlang, whereis, [stam]) of
    {badrpc, _} -> io:format("you need to create out layer node ~n", []),
      start();
    undefined -> ok;
    _ -> ok


  end,

  %% checking if monitor works or the def
  case whereis(monitor) of
    undefined -> case erlang:whereis(defMonitor) of
                   undefined -> register(monitor, self());
                   _ -> nothingtodo
                 end;
    _ -> ok
  end,

  %% intiating the system

  Server = rpc:call('serverNode@127.0.0.1', server, start, []),
  {Gui, Graph} = rpc:call('graphicsNode@127.0.0.1', graphics, init, []),
  Snn = rpc:call('snnNode@127.0.0.1', snn, init, []),
  OutLayerPid = rpc:call('outlayerNode@127.0.0.1', outlayer, init, []),
  ResMonitor = rpc:call('resmonitorNode@127.0.0.1', erlang, whereis, [resmonitor]),
  case erlang:whereis(defMonitor) of
    undefined ->
      DefMonitor = spawn(monitor, createdefmonitor, [self(), Server, Gui, Snn, Graph, ResMonitor, OutLayerPid]);
    Dmonitor -> DefMonitor = Dmonitor
  end,

  %% sending the pids to res monitor to save them
  {resmonitor, 'resmonitorNode@127.0.0.1'} ! {monitor, Server, Gui, Snn, Graph, OutLayerPid},


  io:fwrite("Server is : ~p~n", [Server]),
  io:fwrite("Gui is : ~p~n", [Gui]),
  io:fwrite("Snn is : ~p~n", [Snn]),
  io:fwrite("Graph is : ~p~n", [Graph]),
  io:fwrite("ResMonitor is : ~p~n", [ResMonitor]),
  io:fwrite("Out Layer  is : ~p~n", [OutLayerPid]),

  %% monitoring
  _ = erlang:monitor(process, Server),
  _ = erlang:monitor(process, Gui),
  _ = erlang:monitor(process, Snn),
  _ = erlang:monitor(process, Graph),
  _ = erlang:monitor(process, ResMonitor),
  _ = erlang:monitor(process, OutLayerPid),
  _ = erlang:monitor(process, DefMonitor),

  monitorloop(Server, Gui, Snn, Graph, ResMonitor, OutLayerPid, DefMonitor)
.


%% to handle down messages to restart the application
monitorloop(Server, Gui, Snn, Graph, ResMonitor, OutLayerPid, DefMonitor) ->

  flush(),

  io:format("I (main monitor) waiting in the loop ~n", []),
  receive


    {gui, terminate} ->
      io:format(" monitor: terminating the application ~n", []);%% todo: exit witht the gui need to terminate the application


  %% terminating the other process

    {'DOWN', _, process, ResMonitor, Res} ->
      case rpc:call('monitorNode@127.0.0.1', erlang, whereis, [stam]) of
        {badrpc, _} ->  %% main monitor computer (node) is down
          io:format("I (main monitor) My resMonitor Node ~p died (~p)~n", [ResMonitor, Res]),
          monitorloop(Server, Gui, Snn, Graph, ResMonitor, OutLayerPid, DefMonitor);
        _ ->%% the resmonitor died need to take the def monitor
          io:fwrite("I (main monitor) recieved change message of the active monitor ~n", []),
          Active = rpc:call('resmonitorNode@127.0.0.1', resmonitor, getActive, []),%%blocking way to get the activemonitor
          _ = erlang:monitor(process, Active),
          monitorloop(Server, Gui, Snn, Graph, Active, OutLayerPid, DefMonitor)

%%        ActiveMonitor=rpc:call('monitorNode@127.0.0.1', monitor, getActive, []),
%%        _ = erlang:monitor(process, NewMainMonitor),
%%         start(Server, Gui, Snn, Graph, ActiveMonitor, OutLayer)
      end;



    {'DOWN', _, process, DefMonitor, Res} -> io:format("I (main monitor) My server ~p died (~p)~n", [Server, Res]),
      io:format("I (main monitor) My defmonitor ~p died (~p)~n", [DefMonitor, Res]),
      NewDefMonitor = spawn(monitor, createdefmonitor, [self(), Server, Gui, Snn, Graph, ResMonitor, OutLayerPid]),
      _ = erlang:monitor(process, NewDefMonitor),
      monitorloop(Server, Gui, Snn, Graph, ResMonitor, OutLayerPid, NewDefMonitor);






    {'DOWN', _, process, Server, Res} -> io:format("I (main monitor) My server ~p died (~p)~n", [Server, Res]),
      {graph, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {snn, 'snnNode@127.0.0.1'} ! {monitor, exit},
      {gui, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {outlayer, 'outlayerNode@127.0.0.1'} ! {monitor, exit},
      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();

    {'DOWN', _, process, Gui, Res} -> io:format("I (main monitor) My gui ~p died (~p)~n", [Gui, Res]),
      {graph, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {snn, 'snnNode@127.0.0.1'} ! {monitor, exit},
      {outlayer, 'outlayerNode@127.0.0.1'} ! {monitor, exit},
      spawn(server, stop, [server, 'serverNode@127.0.0.1']),

      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();%% sending stop message to server

    {'DOWN', _, process, Snn, Res} -> io:format("I (main monitor) My Snn ~p died (~p)~n", [Snn, Res]),

      {gui, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {graph, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {outlayer, 'outlayerNode@127.0.0.1'} ! {monitor, exit},
      spawn(server, stop, [server, 'serverNode@127.0.0.1']),

      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();

    {'DOWN', _, process, Graph, Res} -> io:format("I (main monitor) My Graph ~p died (~p)~n", [Graph, Res]),
      {snn, 'snnNode@127.0.0.1'} ! {monitor, exit},
      {gui, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {outlayer, 'outlayerNode@127.0.0.1'} ! {monitor, exit},
      spawn(server, stop, [server, 'serverNode@127.0.0.1']),

      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();
    {'DOWN', _, process, OutLayerPid, Res} -> io:format("I (main monitor) My Graph ~p died (~p)~n", [OutLayerPid, Res]),
      {snn, 'snnNode@127.0.0.1'} ! {monitor, exit},
      {gui, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {graph, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      spawn(server, stop, [server, 'serverNode@127.0.0.1']),

      io:format("restarting the application ~n", []),
      flush(),%% to clear the mail box
      start();



    Rec -> io:format("what the fuck is here:   ~p ~n", [Rec])


  end


.


flush() ->
  receive
    _ -> flush()
  after
    0 -> ok
  end.


createdefmonitor(MonitorPid, Server, Gui, Snn, Graph, ResMonitor, OutLayerPid) ->
  _ = erlang:monitor(process, MonitorPid),
  defmonitor(MonitorPid, Server, Gui, Snn, Graph, ResMonitor, OutLayerPid)
.
defmonitor(MonitorPid, Server, Gui, Snn, Graph, ResMonitor, OutLayerPid) ->

  receive

    {'DOWN', _, process, MonitorPid, Res} ->%% when th active monitor is died the def monitor need to start
      register(defMonitor, self()),
      io:format("old monitor down message is:~p~n", [Res]),
      DefMonitor = spawn(monitor, createdefmonitor, [self(), Server, Gui, Snn, Graph, ResMonitor, OutLayerPid]),%%creating the def for the new active monitor
      _ = erlang:monitor(process, Server),
      _ = erlang:monitor(process, Gui),
      _ = erlang:monitor(process, Snn),
      _ = erlang:monitor(process, Graph),
      _ = erlang:monitor(process, OutLayerPid),
      _ = erlang:monitor(process, DefMonitor),
      monitorloop(Server, Gui, Snn, Graph, ResMonitor, OutLayerPid, DefMonitor);


    _ -> nothingtodo

  end
.

getActive() ->
  case erlang:whereis(defMonitor) of
    undefined -> getActive();
    DefMonitor -> DefMonitor
  end
.
