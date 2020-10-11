%%%-------------------------------------------------------------------
%%% @author kyan
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 07. Oct 2020 15:01
%%%-------------------------------------------------------------------
-module(outlayer).
-author("kyan").

%% API
-export([init/0, start/0]).


%% Initiating the output layer
init() ->


  Pid = spawn(outlayer, start, []),%% At the beginning, there are no pids default is ones
  register(outlayer, Pid),
  Pid.


%% Waiting for terminate message
start() ->
  %%layer:killoutputlayer(),
  layer:start_output_layer(),
  outlayerHandler().

outlayerHandler() ->
  receive
    {monitor, terminate} ->
      erlang:display("Monitor terminating the system~n"),
      layer:killoutputlayer(),
      ok;

    {monitor, exit} -> % Terminated
      erlang:display("Monitor terminating the SNN network output layer~n"),
      layer:killoutputlayer(),
      ok;

    _ -> outlayerHandler()
  end.


