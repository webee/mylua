#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include <stdlib.h> 
#include <unistd.h>
#include <string.h> 
#include <readline/readline.h>
#include <readline/history.h>

#include <signal.h>


/* Static copy of Lua state, as readline has no per-use state */
static lua_State *storedL;


/* This function is called repeatedly by rl_completion_matches inside
   do_completion, each time returning one element from the Lua table. */
static char *generator(const char* text, int state)
{
    size_t len;
    const char *str;
    char *result;
    lua_rawgeti(storedL, -1, state + 1);
    if (lua_isnil(storedL, -1))
        return NULL;
    str = lua_tolstring(storedL, -1, &len);
    result = strndup(str, len);
    lua_pop(storedL, 1);
    return result;
}

/* This function is called by readline() when the user wants a completion. */
static char **do_completion(const char *text, int start, int end)
{
    int oldtop = lua_gettop(storedL);
    char **matches = NULL;

    lua_pushlightuserdata(storedL, (void *)do_completion);
    lua_gettable(storedL, LUA_REGISTRYINDEX);

    rl_completion_suppress_append = 1;

    if (lua_isfunction(storedL, -1)) {
        lua_pushstring(storedL, text);
        lua_pushstring(storedL, rl_line_buffer);
        lua_pushinteger(storedL, start + 1);
        lua_pushinteger(storedL, end + 1);
        if (!lua_pcall(storedL, 4, 1, 0) && lua_istable(storedL, -1))
            matches = rl_completion_matches(text, generator);
    }
    lua_settop(storedL, oldtop);

    return matches;
}


/* Lua bindings */
static int setcompleter(lua_State *L)
{
    lua_pushlightuserdata(L, (void *)do_completion);
    lua_pushvalue(L, 1);
    lua_settable(L, LUA_REGISTRYINDEX);

    return 0;
}

static int redisplay(lua_State *L)
{
    rl_forced_update_display();
    return 0;
}

static int l_readline(lua_State* L)
{
    const char* prompt = lua_tostring(L,1);
    char *line = readline(prompt);
    if (line) {
        lua_pushstring(L, line);
        free(line); // Lua makes a copy...
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static char history_file[128];
static void set_history_file(void)
{
    char *home = getenv("HOME");
    strcpy(history_file, home);
    strcat(history_file, "/.mylua_history");
}

static int l_addhistory(lua_State* L)
{
    const char *res = lua_tostring(L, 1);
    if (strlen(res) > 0)
        add_history(res);
    return 0;
}

static int l_readhistory(lua_State* L)
{
    read_history(history_file);
    return 0;
}

static int l_writehistory(lua_State* L)
{
    write_history(history_file);
    return 0;
}

static int l_chdir(lua_State* L)
{
    const char *path = luaL_checkstring(L, 1);
    if (chdir(path)) {
        perror("chdir");
    }
    return 0;
}

void sig_int(int sig)
{
    write_history(history_file);
    printf("\nKeyboardInterrupt");
}

void init_sig(void)
{
    signal(SIGINT, sig_int);
    signal(SIGTERM, sig_int);
    signal(SIGQUIT, sig_int);
}

static const struct luaL_Reg lib[] = {
    {"_set",        setcompleter},
    {"redisplay",   redisplay},
    {"readline",    l_readline},
    {"addhistory",  l_addhistory},
    {"readhistory", l_readhistory},
    {"writehistory",l_writehistory},
    {"chdir",  l_chdir},
    {NULL, NULL},
};

int luaopen_myreadline(lua_State *L)
{
    luaL_newlib(L, lib);
    storedL = L;

    rl_basic_word_break_characters = " \t\n\"\\'><;:%~!@#$%^&*()-+={}[].,";
    rl_attempted_completion_function = do_completion;

    set_history_file();
    init_sig();

    return 1;
}
