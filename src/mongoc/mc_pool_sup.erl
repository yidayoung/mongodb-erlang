%%%-------------------------------------------------------------------
%%% @author tihon
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 17. Nov 2015 12:47
%%%-------------------------------------------------------------------
-module(mc_pool_sup).
-author("tihon").

-behaviour(supervisor).

%% API
-export([start_link/0, start_pool/2, stop_pool/1]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).


%%%===================================================================
%%% API functions
%%%===================================================================
start_pool(SizeArgs, WorkerArgs) ->
  PoolArgs = [{worker_module, mc_worker}] ++ SizeArgs,
  supervisor:start_child(?MODULE, [PoolArgs, WorkerArgs]).

stop_pool(Pid) ->
  poolboy:stop(Pid).

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link() ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
  supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%%
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
  {ok, {SupFlags :: {RestartStrategy :: supervisor:strategy(),
    MaxR :: non_neg_integer(), MaxT :: non_neg_integer()},
    [ChildSpec :: supervisor:child_spec()]
  }} |
  ignore |
  {error, Reason :: term()}).
init([]) ->
  {ok, {{simple_one_for_one, 10, 10},
    [{worker_pool, {poolboy, start_link, []}, transient, 5000, worker, [poolboy]}]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================