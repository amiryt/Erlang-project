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
-export([init/0, start/0]).

%% Initiate the network input layer
init() ->


  Pid = spawn(snn, start, []),%% At the beginning, there are no pids default is ones
  register(snn, Pid),

  Pid.


%% Starting the input layer an handling the message
start() ->
  %%layer:killinputlayer(),
  layer:start(1, 1, 'outlayerNode@127.0.0.1'),
  snnHandler().

%% Handles message of the input layer
snnHandler() ->
  receive
    {monitor, terminate} ->
      erlang:display("Monitor terminating the system~n"),
      layer:killinputlayer(),
      ok;

    {monitor, exit} ->
      erlang:display("monitor terminating the SNN network input layer~n"),
      layer:killinputlayer(),
      ok;

    {test, InData} ->
      layer:active_input_layer(InData),
      snnHandler();

    _ -> snnHandler()
  end.