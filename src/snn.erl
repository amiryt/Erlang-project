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

%% initiate the network input layer
init() ->

  Pid = spawn(snn, start, []),
  register(snn, Pid),
  Pid
.

%% starting the input layer an handling the message
start() ->

  layer:start(1, 1, 'outlayerNode@127.0.0.1'),
  snnHandler()

.

%% handle message of the input layer
snnHandler() ->

  receive
    {monitor, exit} ->
      layer:killinputlayer(),
      ok;

    {test, InData} ->
      layer:active_input_layer(InData),
      snnHandler()
  ;

    _ -> nothingtodo

  end


.

