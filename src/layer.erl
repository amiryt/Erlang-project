%%%-------------------------------------------------------------------
%%% @author amiryt
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 19. ספט׳ 2020 12:44
%%%-------------------------------------------------------------------
-module(layer).
-author("amiryt").

%% gen_server callbacks
-export([start/0, active_input_layer/2, change_input_layer/2]).
-record(neurons, {input_layer = 5, output_layer = 4}).

start() ->
  Neurons = #neurons{},
  In = element(2, Neurons),
  Out = element(3, Neurons),
  ParaMap =
    maps:put(dt, 0.125,
      maps:put(simulation_time, 50,
        maps:put(t_rest, 0,
          maps:put(rm, 1,
            maps:put(cm, 10,
              maps:put(tau_ref, 4,
                maps:put(vth, 1,
                  maps:put(v_spike, 0.5,
                    maps:put(i_app, 0, maps:new()))))))))),
  ets:new(neuronEts, [ordered_set, named_table]), % For backup the settings of the neuron
  ets:new(weightsEts, [ordered_set, named_table]), % For easy access to the weights
%%  TODO: Have difference between input (16x16 LIF) to output (4 only sends out results)
  initiate_layer(1, In, ParaMap, neuronEts), % Input layer - 5 neurons
  initiate_layer(In + 1, In + Out, ParaMap, neuronEts), % Output layer - 4 neurons
%% TODO: Return this
  Weights_List = ["16.0\t26\t36.65\t46\t56", "17\t27\t37\t47\t57.8", "18\t28\t38\t48\t58", "19\t29\t39\t49\t59"],
%%  Weights_List = get_file_contents("weights.txt"),
  Weights = [list_to_numbers(length(string:tokens(X, "\t")), string:tokens(X, "\t")) || X <- Weights_List], % Splits from the tab
  Weights_Trans = transpose(Weights), % Now we insert in the correct way the weights
  backup_weights(1, In + 1, Weights_Trans, weightsEts), % Save the weights in separate ets to have a backup of them in case we will need
  initiate_weights(1, In, In + 1, In + Out, weightsEts, neuronEts), % Setting the weights by sending them to the neurons in the output layer
%%  TODO: Delete this
  Length = math:ceil(maps:get(simulation_time, ParaMap) / maps:get(dt, ParaMap)),
%%  TODO: I suppose to be the same for all the neurons in the input layer
%%  I = [1, 0, 0, 1, 0],
  I = list_same(1.5, Length + 1),
%%  change_input_layer(In, ParaMap),
  neuron:change_weights([1,2,3,4,5,6,7], 1),
  active_input_layer(1, I),
  hey.

%% @doc  Receives:   In - Number of neurons in the input layer
%%                            I - The information from the picture
%%                Sends the information arrived from the user's picture to the input layer
%%                This information would come from the spike train that would be made with receptive_field
active_input_layer(In, I) ->
  Input_Numbers = lists:seq(1, In),
  Input_Pids = [{X, element(3, hd(ets:lookup(neuronEts, X)))} || X <- Input_Numbers],
  send_data(Input_Pids, I).


%% @doc  Receives:   In - Number of neurons in the input layer
%%                            ParaMap - The map of parameters (can be changed)
%%                Changes the parameters of the neurons in the input layer
change_input_layer(In, ParaMap) ->
  Input_Numbers = lists:seq(1, In),
  Input_Pids = [{X, element(3, hd(ets:lookup(neuronEts, X)))} || X <- Input_Numbers],
  send_parameters(Input_Pids, ParaMap).
%% --------------------------------------------------------------------------------------
%%                          LAYER CONFIGURATION FUNCTIONS
%% --------------------------------------------------------------------------------------

%% @doc  Receives: Input_tuple - {Number, Pid of that input neuron}
%%                            I - The information from the picture - ALL OF THEM ARE THE SAME
%%                Sending for all of those neurons the current in order to activate the LIF
send_data([], _) ->
  io:format("All information passed the input layer~n");
send_data(Input_tuple, I) ->
  {Neuron_Number, Pid} = hd(Input_tuple),
  Pid ! {new_data, {Neuron_Number, I}},
  send_data(tl(Input_tuple), I).


%% @doc  Receives: Input_tuple - {Number, Pid of that input neuron}
%%                          ParaMap - The new parameters map
%%                Sending the new parameters for the neurons
send_parameters([], _) ->
  io:format("All parameters passed the input layer~n");
send_parameters(Input_tuple, ParaMap) ->
  {Neuron_Number, Pid} = hd(Input_tuple),
  Pid ! {new_parameters, {Neuron_Number, ParaMap}},
  send_parameters(tl(Input_tuple), ParaMap).


%% @doc  Receives: N - Number of neurons to be made
%%                StartPoint - The number of neuron we start from
%%                ParaMap - The map of the parameters
%%                EtsName - The ets name (if we use "bag", we need the ID!!)
%%                Creates N neurons and sends the information to the manager server
initiate_layer(Finish, N, _, _) when Finish == N + 1 ->
  io:format("Finished building layer~n");
initiate_layer(StartPoint, N, ParaMap, EtsName) ->
  io:format("Layer(initiate_layer): Neuron ~p created!~n", [StartPoint]),
  Neuron_info = create_neuron(regular, StartPoint, ParaMap),
  ets:insert(EtsName, Neuron_info),
  initiate_layer(StartPoint + 1, N, ParaMap, EtsName).


%% @doc  Receives: Number - The number of the neuron
%%                Start_Option - If we start "regular" or from "restore"
%%                ParaMap - The map of the parameters
%%      Returns:  A tuple: {Neuron_number, Neuron_pid, Parameters_map}
create_neuron(Start_Option, Number, ParaMap) ->
%%  TODO: Add here self() (of the layer) to send the neuron
  Pid_Neuron = spawn(fun() -> actions_neuron(Number) end), % This is the Pid of the neuron
%%  sys:trace(Pid, true),
  Pid_Neuron ! {create, {Number, self()}, Start_Option, ParaMap},
  receive
    Info -> Info
  end.

%% @doc  Receives: Neuron_Number - The number of the neuron
%%      This function is response on the connections between each neuron to the system (which are the layers)
actions_neuron(Neuron_Number) ->
  receive
    {create, {Number, Sender_Pid}, Operation_Mode, ParaMap} when Number == Neuron_Number ->
      {ok, NeuronStatem_Pid} = neuron:start_link(Number, Operation_Mode, self(), ParaMap),
%%      TODO: Understand if we want to save the pid from the statem (Neuron_Pid) or the process in the layer (self())
      Sender_Pid ! {Neuron_Number, NeuronStatem_Pid, self(), ParaMap}; % {1, Pid68 (statem - for tracking), Pid71 (neuron pid in the layer), parameters map}
    {weights, Sender_Pid, Weights} ->
      io:format("Entered~p~n", [Neuron_Number]),
      neuron:change_weights(Weights, Neuron_Number);
    {spikes_from_neuron, Spike_trains} -> % The current received from the neuron
%%      io:format("New Spikes from neuron~n"),
      Num_Spikes = [lists:sum(X) || X <-Spike_trains],
      io:format("Neuron~p~n", [Num_Spikes]),
%%      TODO: Send from input neuron to output neuron how many spikes there were
      hey;
    {new_data, {Neuron_Number, I}} ->
%%      io:format("New Data~n"),
      neuron:new_data(I, Neuron_Number);
    {new_parameters, {Neuron_Number, ParaMap}} ->
      neuron:change_parameters(ParaMap, Neuron_Number)
  end,
  actions_neuron(Neuron_Number). % Inorder to stay in the loop of receiving orders

%% --------------------------------------------------------------------------------------
%%                          WEIGHTS BACKUP FUNCTIONS
%% --------------------------------------------------------------------------------------

%% @doc  Receives: Output_Len - Number of neurons in the output layer
%%                Input_Neuron - The number of the input neuron we work on
%%                Weights - A list of weights
%%                WeightsEts - The ets name of weights
%%                Backup all the weights of the neurons in an ets
backup_weights(_, _, [], _) ->
  io:format("Finished backup weights~n");
backup_weights(Input_Neuron, Output_Len, Weights, WeightsEts) ->
  io:format("Layer(backup_weights): Setting output neuron weights backup~n"),
%%  Weights_List = list_to_numbers(length(string:tokens(hd(Weights), "\t")), string:tokens(hd(Weights), "\t")), % Splits from the tab
  save_weights(Input_Neuron, Output_Len, hd(Weights), WeightsEts), % We save the weights in order to have a backup of them
  backup_weights(Input_Neuron + 1, Output_Len, tl(Weights), WeightsEts).


%% @doc  Receives: Start - The neuron we work on from input layer
%%                Input_Len - Number of neurons in the input layer
%%                Output_Neuron - The number of the output neuron we work on
%%                Weights_List - A list of weights for the specific output neuron
%%                WeightsEts - The ets name of weights
%%                Save all the weights of the neurons
save_weights(Start, _, [], _)  ->
  io:format("Finished saving weights for neuron~p~n", [Start]);
save_weights(Start, Output_Neuron, Weights_List, WeightsEts) ->
  io:format("Saving weight ~p between neuron~p to neuron~p~n", [hd(Weights_List), Start, Output_Neuron]),
  ets:insert(WeightsEts, {{Start, Output_Neuron}, hd(Weights_List)}),
%%  ets:insert(WeightsEts, {{Output_Neuron, Start}, hd(Weights_List)}), % Not sure about that
  save_weights(Start, Output_Neuron + 1, tl(Weights_List), WeightsEts).

%% --------------------------------------------------------------------------------------
%%                          WEIGHTS CONFIGURATION FUNCTIONS
%% --------------------------------------------------------------------------------------

%% @doc  Receives: Input_Len - Number of neurons in the input layer
%%                Output_Neuron - The number of the output neuron we work on
%%                Finish - The number of the last neuron in the output layer
%%                WeightsEts - The ets name of weights
%%                NeuronEts - The ets name of neurons
%%                Sets all the weights of the neurons
initiate_weights(Output_Neuron, _, Output_Neuron, _, _, _) ->
  io:format("Finished setting weights in network~n");
initiate_weights(Input_Neuron, Input_Len, Output_Neuron, Finish, WeightsEts, NeuronEts) ->
  io:format("Layer(initiate_weights): Setting neuron~p weights~n", [Input_Neuron]),
  Neurons_Numbers = lists:seq(Input_Len + 1, Finish),
  set_weights(Neurons_Numbers, Input_Neuron, WeightsEts, NeuronEts, []),
  initiate_weights(Input_Neuron + 1, Input_Len, Output_Neuron, Finish, WeightsEts, NeuronEts).


%% @doc  Receives: Neurons_Numbers - The neurons of the output layer
%%                Input_Neuron - The number of the input neuron we work on
%%                WeightsEts - The ets name of weights
%%                NeuronsEts - The ets name of neurons
%%                Set all the weights of the output neurons with that "Input_Neuron"
set_weights([], Input_Neuron, _, NeuronEts, Weights_List) ->
  Weights = lists:reverse(Weights_List),
  Input_Neuron_Info = hd(ets:lookup(NeuronEts, Input_Neuron)),
  Pid_Input = element(3, Input_Neuron_Info),
  Pid_Input ! {weights, self(), Weights}, % The layer sends request to the neuron to change his weights
  finished;
set_weights(Neurons_Numbers, Input_Neuron, WeightsEts, NeuronEts, Weights_List) ->
  io:format("Setting weight between neuron~p to neuron~p~n", [Input_Neuron, hd(Neurons_Numbers)]),
  Weight_info = hd(ets:lookup(WeightsEts, {Input_Neuron, hd(Neurons_Numbers)})),
  Weight = element(2, Weight_info),
  set_weights(tl(Neurons_Numbers), Input_Neuron, WeightsEts, NeuronEts, [Weight | Weights_List]).

%% --------------------------------------------------------------------------------------


%% --------------------------------------------------------------------------------------
%%                          SUPPORT FUNCTIONS
%% --------------------------------------------------------------------------------------

%% @doc Receives: FileName - The name of the file we want to read
%%      Returns:  The list of the lines of the file

% Get the contents of a text file into a list of lines.
% Each line has its trailing newline removed.
get_file_contents(Name) ->
  {ok, File} = file:open(Name, [read]),
  Rev = get_all_lines(File, []),
  lists:reverse(Rev).

% Auxiliary function for get_file_contents.
get_all_lines(File, Partial) ->
  case io:get_line(File, "") of
    eof -> file:close(File),
      Partial;
    Line -> {Strip, _} = lists:split(length(Line), Line),
      get_all_lines(File, [Strip | Partial])
  end.


%% @doc  Receives: Num - The number we want
%%                Len - Number of times that "Num" would appear
%%      Returns:  A list with the same elements Len times
list_same(_, Finish) when (Finish == 0) ->
  [];
list_same(Num, Len) ->
  [Num | list_same(Num, Len - 1)].


%% @doc Receives: List - List of strings
%%                         Len - List length
%%      Returns:  A list of floats & integers
list_to_numbers(0, []) ->
  [];
list_to_numbers(Len, [H | T]) ->
  [list_to_number(H) | list_to_numbers(Len - 1, T)].


%% @doc Receives: Str - A list that represent one string
%%      Returns:  A float or integer
list_to_number(Str) ->
  try list_to_float(Str) of
    _ ->
      list_to_float(Str)
  catch
    error:_ ->
      try list_to_integer(Str) of
        _ ->
          list_to_integer(Str)
      catch
        error:Error -> {error, Error}
      end
  end.

%% @doc Receives: M - Matrix
%%      Returns:  Transformed matrix
transpose([[]|_]) ->
  [];
transpose(M) ->
  [lists:map(fun hd/1, M) | transpose(lists:map(fun tl/1, M))].