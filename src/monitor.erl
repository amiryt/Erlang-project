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
  spawn(monitor, start, []).


start() ->
  flush(),
  timer:sleep(2000),

  %% Checks if the node is on
  case rpc:call('resmonitorNode@127.0.0.1', erlang, whereis, [resmonitor]) of
    {badrpc, _} -> io:format("You need to create resmonitor node! ~n", []),
      start();

    undefined ->
      io:format("You need to create resmonitor process! ~n", []),
      start();

    _ -> ok
  end,

  %% Checks if the node is on
  case rpc:call('serverNode@127.0.0.1', erlang, whereis, [server]) of
    {badrpc, _} -> io:format("You need to create server node! ~n", []),
      start();

    undefined -> ok;

    _ -> ok
  end,

  %% Checks if the node is on
  case rpc:call('graphicsNode@127.0.0.1', erlang, whereis, [gui]) of
    {badrpc, _} -> io:format("You need to create graphics node! ~n", []),
      start();

    undefined ->
      ok;

    _ -> ok
  end,

  %% Checks if the node is on
  case rpc:call('snnNode@127.0.0.1', erlang, whereis, [snn]) of
    {badrpc, _} -> io:format("You need to create snn node! ~n", []),
      start();

    undefined ->
      ok;

    _ -> ok
  end,

%%  Checks if the node is on
  case rpc:call('outlayerNode@127.0.0.1', erlang, whereis, [stam]) of
    {badrpc, _} -> io:format("You need to create out layer node! ~n", []),
      start();

    undefined -> ok;
    _ -> ok
  end,

  %% Checks if the monitor works or the defMonitor
  case whereis(monitor) of
    undefined -> case erlang:whereis(defMonitor) of
                   undefined -> register(monitor, self());
                   _ -> nothingtodo
                 end;
    _ -> ok
  end,

  %% Initiating the system
  Server = rpc:call('serverNode@127.0.0.1', server, start, []),
  {Gui, Graph} = rpc:call('graphicsNode@127.0.0.1', graphics, init, []),
  Snn = rpc:call('snnNode@127.0.0.1', snn, init, []),
  OutLayerPid = rpc:call('outlayerNode@127.0.0.1', outlayer, init, []),
  ResMonitor = rpc:call('resmonitorNode@127.0.0.1', erlang, whereis, [resmonitor]),

  case get(defMon) of
    undefined ->
      DefMonitor = spawn(monitor, createdefmonitor, [self(), Server, Gui, Snn, Graph, ResMonitor, OutLayerPid]),
    put(defMon,DefMonitor);
    Dmonitor -> DefMonitor = Dmonitor
  end,

  %% Sending the pids to res monitor to save them
  {resmonitor, 'resmonitorNode@127.0.0.1'} ! {monitor, Server, Gui, Snn, Graph, OutLayerPid},


  io:fwrite("Server is: ~p~n", [Server]),
  io:fwrite("Gui is: ~p~n", [Gui]),
  io:fwrite("SNN is: ~p~n", [Snn]),
  io:fwrite("Graphs is: ~p~n", [Graph]),
  io:fwrite("ResMonitor is: ~p~n", [ResMonitor]),
  io:fwrite("Out Layer is: ~p~n", [OutLayerPid]),

  %% Monitoring
  RefServer = erlang:monitor(process, Server),
  RefGui = erlang:monitor(process, Gui),
  RefSnn = erlang:monitor(process, Snn),
  RefGraph = erlang:monitor(process, Graph),
  RefRes = erlang:monitor(process, ResMonitor),
  RefOL = erlang:monitor(process, OutLayerPid),
  RefDefM = erlang:monitor(process, DefMonitor),
  put(refServer,RefServer),
  put(refGui,RefGui),
  put(refSnn,RefSnn),
  put(refGraph,RefGraph),
  put(refRes,RefRes),
  put(refOL,RefOL),
  put(refDefM,RefDefM),
  monitorloop(Server, Gui, Snn, Graph, ResMonitor, OutLayerPid, DefMonitor).


%% Handle down messages to restart the application
monitorloop(Server, Gui, Snn, Graph, ResMonitor, OutLayerPid, DefMonitor) ->
  spawn(server, activeMonitor, [server, 'serverNode@127.0.0.1', self(),node()]),
  flush(),
  io:format("Main monitor: Waiting in the loop ~n", []),
  receive
    {server,terminate}->
      io:format("Main monitor: Terminating the system~n", []),
      _ = erlang:demonitor( get(refServer)),
      _ = erlang:demonitor( get(refGui)),
      _ = erlang:demonitor( get(refSnn)),
      _ = erlang:demonitor( get(refGraph)),
      _ = erlang:demonitor( get(refRes)),
      _ = erlang:demonitor( get(refOL)),
      _ = erlang:demonitor(get(refDefM)),

      Server!{monitor, terminate},
      Gui!{monitor, terminate},
      Snn!{monitor, terminate},
      OutLayerPid!{monitor, terminate},
      Graph!{monitor, terminate},
      ResMonitor!{monitor, terminate},
      DefMonitor!{monitor, terminate},

      io:format("Main monitor: Terminate messages sent ~n", []),
      flush();

    {gui, terminate} ->
      io:format("Monitor: Terminating the application ~n", []);

  %% Terminating the other process
    {'DOWN', _, process, ResMonitor, Res} ->
      case rpc:call('monitorNode@127.0.0.1', erlang, whereis, [stam]) of
        {badrpc, _} ->  %% main monitor computer (node) is down
          io:format("Main monitor: My resMonitor Node ~p died (~p)~n", [ResMonitor, Res]),
          monitorloop(Server, Gui, Snn, Graph, ResMonitor, OutLayerPid, DefMonitor);

        _ ->%% the resMonitor died need to take the def monitor
          io:fwrite("Main monitor: Recieved change message of the active monitor ~n", []),
          Active = rpc:call('resmonitorNode@127.0.0.1', resmonitor, getActive, []),
          _ = erlang:monitor(process, Active),
          monitorloop(Server, Gui, Snn, Graph, Active, OutLayerPid, DefMonitor)
      end;

    {'DOWN', _, process, DefMonitor, Res} -> io:format("Main monitor: My server ~p died (~p)~n", [Server, Res]),
      io:format("Main monitor: My defmonitor ~p died (~p)~n", [DefMonitor, Res]),
      NewDefMonitor = spawn(monitor, createdefmonitor, [self(), Server, Gui, Snn, Graph, ResMonitor, OutLayerPid]),
      _ = erlang:monitor(process, NewDefMonitor),
      monitorloop(Server, Gui, Snn, Graph, ResMonitor, OutLayerPid, NewDefMonitor);

    {'DOWN', _, process, Server, Res} -> io:format("Main monitor: My server ~p died (~p)~n", [Server, Res]),
      {graph, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {snn, 'snnNode@127.0.0.1'} ! {monitor, exit},
      {gui, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {outlayer, 'outlayerNode@127.0.0.1'} ! {monitor, exit},
      io:format("Restarting the application ~n", []),
      flush(), %% Clears the mail box
      start();

    {'DOWN', _, process, Gui, Res} -> io:format("Main monitor: My GUI ~p died (~p)~n", [Gui, Res]),
      {graph, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {snn, 'snnNode@127.0.0.1'} ! {monitor, exit},
      {outlayer, 'outlayerNode@127.0.0.1'} ! {monitor, exit},
      spawn(server, stop, [server, 'serverNode@127.0.0.1']),
      io:format("Restarting the application ~n", []),
      flush(),
      start();

    {'DOWN', _, process, Snn, Res} -> io:format("Main monitor: My Snn ~p died (~p)~n", [Snn, Res]),

      {gui, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {graph, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {outlayer, 'outlayerNode@127.0.0.1'} ! {monitor, exit},
      spawn(server, stop, [server, 'serverNode@127.0.0.1']),
      io:format("Restarting the application ~n", []),
      flush(),
      start();

    {'DOWN', _, process, Graph, Res} -> io:format("Main monitor: My Graph ~p died (~p)~n", [Graph, Res]),
      {snn, 'snnNode@127.0.0.1'} ! {monitor, exit},
      {gui, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {outlayer, 'outlayerNode@127.0.0.1'} ! {monitor, exit},
      spawn(server, stop, [server, 'serverNode@127.0.0.1']),
      io:format("Restarting the application ~n", []),
      flush(),
      start();

    {'DOWN', _, process, OutLayerPid, Res} -> io:format("Main monitor: My Graph ~p died (~p)~n", [OutLayerPid, Res]),
      {snn, 'snnNode@127.0.0.1'} ! {monitor, exit},
      {gui, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      {graph, 'graphicsNode@127.0.0.1'} ! {monitor, exit},
      spawn(server, stop, [server, 'serverNode@127.0.0.1']),
      io:format("Restarting the application ~n", []),
      flush(),
      start();

    Rec -> io:format("what the fuck is here:   ~p ~n", [Rec])
  end.


flush() ->
  receive
    _ -> flush()
  after
    0 -> ok
  end.


createdefmonitor(MonitorPid, Server, Gui, Snn, Graph, ResMonitor, OutLayerPid) ->
  RefMon = erlang:monitor(process, MonitorPid),
  put(refMon,RefMon),
  defmonitor(MonitorPid, Server, Gui, Snn, Graph, ResMonitor, OutLayerPid).


defmonitor(MonitorPid, Server, Gui, Snn, Graph, ResMonitor, OutLayerPid) ->
  receive
    {monitor, terminate}->
      _ = erlang:demonitor( get(refMon)),
      ok;

    {'DOWN', _, process, MonitorPid, Res} ->%% when th active monitor is died the def monitor need to start
      register(defMonitor, self()),
      io:format("DefMonitor: Old monitor down message is: ~p~n", [Res]),
      DefMonitor = spawn(monitor, createdefmonitor, [self(), Server, Gui, Snn, Graph, ResMonitor, OutLayerPid]),%%creating the def for the new active monitor
      put(defMon,DefMonitor),
      RefServer = erlang:monitor(process, Server),
      RefGui = erlang:monitor(process, Gui),
      RefSnn = erlang:monitor(process, Snn),
      RefGraph = erlang:monitor(process, Graph),
      RefRes = erlang:monitor(process, ResMonitor),
      RefOL = erlang:monitor(process, OutLayerPid),
      RefDefM = erlang:monitor(process, DefMonitor),
      put(refServer,RefServer),
      put(refGui,RefGui),
      put(refSnn,RefSnn),
      put(refGraph,RefGraph),
      put(refRes,RefRes),
      put(refOL,RefOL),
      put(refDefM,RefDefM),
      monitorloop(Server, Gui, Snn, Graph, ResMonitor, OutLayerPid, DefMonitor);

    _ -> nothingtodo
  end.


getActive() ->
  case erlang:whereis(defMonitor) of
    undefined -> getActive();
    DefMonitor -> DefMonitor
  end.
