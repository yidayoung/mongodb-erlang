-module(mc_cursor).


-include("mongo_protocol.hrl").


-export([create/5, rest/1, rest/2, take/3, take/2, close/1, next/1, next/2, next_batch/1, next_batch/2]).


-record(cursor, {
    connection :: mc_worker:connection(),
    collection :: atom(),
    cursor :: integer(),
    batchsize :: integer(),
    batch :: [bson:document()]
}).



cursor_default_timeout() ->
    application:get_env(mongodb, cursor_timeout, infinity).


%% @private
next_i(#cursor{batch = [Doc | Rest]} = State, _Timeout) ->
    {{Doc}, State#cursor{batch = Rest}};
next_i(#cursor{batch = [], cursor = 0} = State, _Timeout) ->
    {{}, State};
next_i(#cursor{batch = []} = State, Timeout) ->
    Reply = gen_server:call(
        State#cursor.connection,
        #getmore{
            collection = State#cursor.collection,
            batchsize = State#cursor.batchsize,
            cursorid = State#cursor.cursor
        },
        Timeout),
    Cursor = Reply#reply.cursorid,
    Batch = Reply#reply.documents,
    next_i(State#cursor{cursor = Cursor, batch = Batch}, Timeout).

%% @private
rest_i(State, infinity, Timeout) ->
    rest_i(State, -1, Timeout);
rest_i(State, Limit, Timeout) when is_integer(Limit) ->
    {Docs, UpdatedState} = rest_i(State, [], Limit, Timeout),
    {lists:reverse(Docs), UpdatedState}.

%% @private
rest_i(State, Acc, 0, _Timeout) ->
    {Acc, State};
rest_i(State, Acc, Limit, Timeout) ->
    case next_i(State, Timeout) of
        {{}, UpdatedState} ->
            {Acc, UpdatedState};
        {{Doc}, UpdatedState} ->
            rest_i(UpdatedState, [Doc | Acc], Limit - 1, Timeout)
    end.

%% @private
format_batch([#{<<"cursor">> := #{<<"firstBatch">> := Batch}}]) ->
    Batch;
format_batch(Reply) ->
    Reply.


create(Connection, Collection, Cursor, BatchSize, Batch) ->
    #cursor{
        connection = Connection,
        collection = Collection,
        cursor = Cursor,
        batchsize = BatchSize,
        batch = format_batch(Batch)
    }.

rest(Cursor) ->
    rest(Cursor, cursor_default_timeout()).
rest(Cursor, TimeOut) ->
    case rest_i(Cursor, infinity, TimeOut) of
        {Reply, #cursor{cursor = 0} = NewCursor} ->
            close(NewCursor),
            {Reply, NewCursor};
        {Reply, NewCursor} ->
            {Reply, NewCursor}
    end.

take(Cursor, Limit) ->
    take(Cursor, Limit, cursor_default_timeout()).
take(Cursor, Limit, TimeOut) ->
    case rest_i(Cursor, Limit, TimeOut) of
        {Reply, #cursor{cursor = 0} = NewCursor} ->
            close(NewCursor),
            {Reply, NewCursor};
        {Reply, NewCursor} ->
            {Reply, NewCursor}
    end.

next(Cursor) ->
    next(Cursor, cursor_default_timeout()).
next(Cursor, TimeOut) ->
    case next_i(Cursor, TimeOut) of
        {Reply, #cursor{cursor = 0, batch = []} = NewCursor} ->
            close(Cursor),
            {Reply, NewCursor};
        {Reply, NewCursor} ->
            {Reply, NewCursor}
    end.

next_batch(Cursor) ->
    next_batch(Cursor, cursor_default_timeout()).
next_batch(#cursor{batchsize = Limit} = Cursor, TimeOut) ->
    case rest_i(Cursor, Limit, TimeOut) of
        {Reply, #cursor{cursor = 0} = NewCursor} ->
            close(NewCursor),
            {Reply, NewCursor};
        {Reply, NewCursor} ->
            {Reply, NewCursor}
    end.


close(Cursor) ->
    gen_server:call(Cursor#cursor.connection, #killcursor{cursorids = [Cursor#cursor.cursor]}).