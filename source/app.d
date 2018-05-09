import std.stdio;
import derelict.sdl2.sdl;
import derelict.sdl2.image;
import derelict.sdl2.ttf;
import derelict.opengl;
import std.typecons : Tuple;
import std.algorithm.comparison : min, max;
import std.math : fabs;

//mixin glFreeFuncs!(GLVersion.gl33);
//mixin glContext!(GLVersion.gl33);
//GLContext context;

enum maxGLVersion = GLVersion.gl33;
enum supportDeprecated = true;

// Required imports
static if(!supportDeprecated) mixin(glImports);
else mixin(gl_depImports);

// Type declarations should be outside of the struct
mixin glDecls!(maxGLVersion, supportDeprecated);
//struct MyContext {
    mixin glFuncs!(maxGLVersion, supportDeprecated);
    mixin glLoaders!(maxGLVersion, supportDeprecated);
//}
//MyContext context;

enum screenHeight = 480;
enum screenWidth = 640;

void InitSDL(ref SDL_Window *screen, ref SDL_GLContext context)
{
    DerelictGL3.load();

    if (SDL_Init(SDL_INIT_VIDEO) < 0)
    {
        writefln("SDL_Init Error: %s", SDL_GetError());
        return;
    }

    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_Window *scr = SDL_CreateWindow("Automatic PONG",
                                          SDL_WINDOWPOS_UNDEFINED,
                                          SDL_WINDOWPOS_UNDEFINED,
                                          screenWidth, screenHeight,
                                          SDL_WINDOW_OPENGL);
    if (!scr)
    {
        writefln("Error creating screen: %s", SDL_GetError());
        return;
    }

    context = SDL_GL_CreateContext(scr);

    glEnable(GL_DEPTH_TEST);

    screen = scr;
}

alias vec2f = Tuple!(float, "x", float, "y");

struct GameState
{
    static enum numPlayers = 2;
    // Distance moved by one key press on the OY axis
    static enum dy = 20.;
    // Tolerance
    float eps = 0.001;

    // The state should never be copied
    @disable this(this);

    Ball ball;

    // Initialize the player rackets
    Racket[numPlayers] racket = [Racket(-0.9), Racket(0.9)];

    // Screen limits
    float[2] limits = [-1, 1];

    Score score;
    SDL_Texture* backgroundTexture;
}

struct Score
{
    enum fontSize = 100;
    vec2f pos = vec2f(-0.16, -1);
    float fontWidth = 0.3;
    float fontHeight = 0.3;

    // Score for the two players
    int[2] score;
    SDL_Color textColor = {255,255,255};
    TTF_Font* font;
    SDL_Surface* textSurface;
    SDL_Texture* fontTexture;

    void adjustScore()
    {
        import std.string : toStringz;
        import std.conv : to;
        import core.stdc.stdlib : free;

        string text = to!string(score[0], 10) ~ " - " ~ to!string(score[1], 10);
        free(textSurface);
        free(fontTexture);
        textSurface = TTF_RenderText_Solid(font, toStringz(text), textColor);
        fontTexture = SDL_CreateTextureFromSurface(gRenderer, textSurface);
    }
}

struct Ball
{
    vec2f pos = vec2f(0, 0);
    vec2f speed = vec2f(0.5, 0.5);
    float size = 0.03;
    SDL_Texture* ballTexture;

    void reset()
    {
        pos = vec2f(0, 0);
        speed = vec2f(0.7, 0.7);
        size = 0.03;
    }

    void increaseSpeed()
    {
        import std.random;
        auto rnd = Random();

        float extraX = uniform(0.1, 0.2, rnd);
        float extraY = uniform(0.1, 0.2, rnd);
        if (speed.x <= 0)
            speed.x -= extraX;
        else speed.x += extraX;

        if (speed.y <= 0)
            speed.y -= extraY;
        else speed.y += extraY;
    }
}

struct Racket
{
    // Set the racket on the left or right side of the screen
    this(float x)
    {
        pos.x = x;
    }

    void reset(int player)
    {
        pos.y = 0;
        halfLength = 0.3;
        halfWidth = 0.01;

        if (player == Player.One)
        {
            speed = 0;
            pos.x = -0.9;
        }
        else
        {
            speed = 0.8;
            pos.x = 0.9;
        }
    }

    // Default values
    vec2f pos = vec2f(0, 0);
    float halfLength = 0.3;
    float halfWidth = 0.01;
    float speed = 0.5;
    SDL_Texture* playerTexture;
}

enum Player { One, Two }
enum Direction { Down, Up }

GameState state;

void drawPlayer(int player, ref GameState state)
{
    SDL_Rect r;
    auto racket = state.racket[player];
    r.x = cast(int) ((racket.pos.x - racket.halfWidth + 1) * (screenWidth / 2));
    r.y = cast(int) ((2 - (racket.pos.y + racket.halfLength + 1)) * (screenHeight / 2));
    r.w = cast(int) ((2 * racket.halfWidth) * (screenWidth / 2));
    r.h = cast(int) ((2 * racket.halfLength) * (screenHeight / 2));

    //Update screen
    SDL_RenderCopy(gRenderer, racket.playerTexture, null, &r);
}

void drawBall(ref GameState state)
{
    SDL_Rect r;
    auto ball = state.ball;
    r.x = cast(int) ((ball.pos.x - ball.size + 1) * (screenWidth / 2));
    r.y = cast(int) ((2 - (ball.pos.y + ball.size + 1)) * (screenHeight / 2));
    r.w = cast(int) ((2 * ball.size) * (screenWidth / 2));
    r.h = cast(int) ((2 * ball.size) * (screenHeight / 2));

    //Update screen
    SDL_RenderCopy(gRenderer, ball.ballTexture, null, &r);
}

void drawScore(ref GameState state)
{
    auto score = state.score;
    SDL_Rect r;
    r.x = cast(int) ((score.pos.x + 1) * (screenWidth / 2));
    r.y = cast(int) ((score.pos.y + 1) * (screenHeight / 2));
    r.w = cast(int) ((score.fontWidth) * (screenWidth / 2));
    r.h = cast(int) ((score.fontHeight) * (screenHeight / 2));

    SDL_RenderCopy(gRenderer, score.fontTexture, null, &r);
}

void drawBackground(ref GameState state)
{
    //Render texture to screen
    SDL_RenderCopy(gRenderer, state.backgroundTexture, null, null);
}

void display(ref SDL_Window *screen, ref GameState state)
{
    //Clear screen
    SDL_RenderClear(gRenderer);
    SDL_SetRenderDrawColor(gRenderer, 0xFF, 0xFF, 0xFF, 0xFF);

    drawBackground(state);
    drawPlayer(Player.One, state);
    drawPlayer(Player.Two, state);
    drawBall(state);
    drawScore(state);

    SDL_RenderPresent(gRenderer);
}

void updateBall(ref GameState state, float dt)
{
    auto ball = &state.ball;
    ball.pos.x += dt * ball.speed.x;
    ball.pos.y += dt * ball.speed.y;
}

void moveHumanPlayer(ref GameState state, float dt)
{
    auto player = &state.racket[Player.One];
    player.pos.y += dt * player.speed;

    player.pos.y = min(state.limits[1], player.pos.y);
    player.pos.y = max(state.limits[0], player.pos.y);
}

void moveAIPlayer(ref GameState state, float dt)
{
    auto player = &state.racket[Player.Two];
    auto ball = &state.ball;

    float yDiff = player.pos.y - ball.pos.y;
    if (fabs(yDiff) < state.eps)
        return;

    float dy = -yDiff / fabs(yDiff);
    player.pos.y += dy * dt * player.speed;
}

/**
 * Recieve an array of artificial "intelligence" players.
 */
void updatePlayers(ref GameState state, float dt)
{
    moveHumanPlayer(state, dt);
    moveAIPlayer(state, dt);
}

void checkCollisons(ref GameState state)
{
    auto ball = &state.ball;
    auto playerOne = &state.racket[Player.One];
    auto playerTwo = &state.racket[Player.Two];

    // Check collision with left player
    if (ball.speed.x < 0)
    {
        if (ball.pos.x <= playerOne.pos.x + playerOne.halfWidth &&
            fabs(ball.pos.y - playerOne.pos.y) < playerOne.halfLength)
        {
            ball.speed.x *= -1;
            ball.increaseSpeed();
        }
    }

    // Check collision with right player
    if (ball.speed.x > 0)
    {
        if (ball.pos.x >= playerTwo.pos.x - playerTwo.halfWidth &&
            fabs(ball.pos.y - playerTwo.pos.y) < playerTwo.halfLength)
        {
            ball.speed.x *= -1;
            ball.increaseSpeed();
        }
    }

    // Check collision with lower bound of the screen
    if (ball.pos.y <= state.limits[0] || ball.pos.y >= state.limits[1])
        ball.speed.y *= -1;
}

bool checkGameOver(ref GameState state)
{
    auto ball = &state.ball;
    auto score = &state.score;

    if (ball.pos.x <= state.limits[0])
    {
        score.score[Player.Two]++;
        return true;
    }

    if (ball.pos.x >= state.limits[1])
    {
        score.score[Player.One]++;
        return true;
    }

    return false;
}

void updateGameplay(ref GameState state, float dt)
{
    if (checkGameOver(state))
        initGame(state);
    checkCollisons(state);
    updateBall(state, dt);
    updatePlayers(state, dt);
}

/**
 * Process events from user.
 *
 * Returns:
 *      `true` if user wants to quit; `false` otherwise.
 */
bool processEvents(ref GameState state, float dt)
{
    // Check events
    SDL_Event event;
    while (SDL_PollEvent(&event))
    {
        switch (event.type)
        {
            case SDL_QUIT:
                // Quit the program
                return true;
            case SDL_KEYDOWN:
                processKeydownEv(event, state, dt);
                break;
            case SDL_KEYUP:
                processKeyupEv(event, state, dt);
                break;
            default:
                debug(PongD) writefln("Untreated event %s", event.type);
                break;
        }
    }
    return false;
}

/**
 * Process keyboard events from user.
 */
void processKeydownEv(ref SDL_Event event, ref GameState state, float dt)
{
    auto player = &state.racket[Player.One];
    switch (event.key.keysym.sym)
    {
        case SDLK_UP:
            player.speed = 0.5;
            break;
        case SDLK_DOWN:
            player.speed = -0.5;
            break;
        default:
            debug (PongD) writefln("pressed %s", event.key.keysym);
    }
}

/**
 * Process keyboard events from user.
 */
void processKeyupEv(ref SDL_Event event, ref GameState state, float dt)
{
    auto player = &state.racket[Player.One];
    switch (event.key.keysym.sym)
    {
        case SDLK_UP:
            player.speed = 0;
            break;
        case SDLK_DOWN:
            player.speed = 0;
            break;
        default:
            debug (PongD) writefln("pressed %s", event.key.keysym);
    }
}

SDL_Texture* loadTexture(const(char)[] path)
{
    //The final texture
    SDL_Texture* newTexture = null;

    //Load image at specified path
    SDL_Surface* loadedSurface = IMG_Load(path.ptr);
    if(loadedSurface == null)
    {
        writefln("Unable to load image %s! SDL_image Error: %s\n", path, IMG_GetError());
    }
    else
    {
        //Create texture from surface pixels
        newTexture = SDL_CreateTextureFromSurface(gRenderer, loadedSurface);
        if(newTexture == null)
        {
            writefln("Unable to create texture from %s! SDL Error: %s\n", path, SDL_GetError());
        }

        //Get rid of old loaded surface
        SDL_FreeSurface(loadedSurface);
    }

    return newTexture;
}

bool loadMedia(ref GameState state)
{
    import std.string : toStringz;

    //Loading success flag
    bool success = true;
    SDL_Texture* backgroundTexture;
    SDL_Texture* playerOneTexture;
    SDL_Texture* playerTwoTexture;
    SDL_Texture* ballTexture;
    const(char[]) fontpath = "/usr/share/fonts/truetype/freefont/FreeSerif.ttf";
    SDL_Texture* fontTexture;
    SDL_Surface* textSurface;
    TTF_Font* font;

    //Load PNG texture
    backgroundTexture = loadTexture("res/background.png");
    if(backgroundTexture == null)
    {
        writeln("Failed to load background texture image!");
        success = false;
        goto end;
    }
    state.backgroundTexture = backgroundTexture;

    playerOneTexture = loadTexture("res/playerOne.png");
    if(playerOneTexture == null)
    {
        writeln("Failed to load player one texture image!");
        success = false;
        goto end;
    }
    state.racket[Player.One].playerTexture = playerOneTexture;

    playerTwoTexture = loadTexture("res/playerTwo.png");
    if(playerTwoTexture == null)
    {
        writeln("Failed to load player two texture image!");
        success = false;
        goto end;
    }
    state.racket[Player.Two].playerTexture = playerTwoTexture;

    ballTexture = loadTexture("res/ball.png");
    if(ballTexture == null)
    {
        writeln("Failed to load ball texture image!");
        success = false;
        goto end;
    }
    state.ball.ballTexture = ballTexture;

    font = TTF_OpenFont(fontpath.ptr, state.score.fontSize);
    if (font is null)
    {
        writefln("TTF_OpenFont: %s\n", TTF_GetError());
        success = false;
        goto end;
    }
    state.score.font = font;

end:
    return success;
}

SDL_Renderer *gRenderer;

void initGame(ref GameState state)
{
    state.racket[Player.One].reset(Player.One);
    state.racket[Player.Two].reset(Player.Two);
    state.ball.reset();
    state.score.adjustScore();
}

void main()
{
    import std.conv : to;
    SDL_Window * screen = null;
    SDL_GLContext context = null;

    auto prevTicks = SDL_GetTicks();
    float deltaTimeConstant = 1000.;
    InitSDL(screen, context);

    SDL_RendererFlags none;
    gRenderer = SDL_CreateRenderer(screen, -1, none);

    int imgFlags = IMG_INIT_PNG;
    if(!(IMG_Init(imgFlags) & imgFlags))
    {
        writeln("SDL_image could not initialize! SDL_image Error: %s\n", IMG_GetError());
        return;
    }

    // For fonts
    if (TTF_Init() < 0)
    {
        writeln("TTF_Init error");
    }

    if (!loadMedia(state))
    {
        writeln("Failed to load media");
        return;
    }
    initGame(state);

    bool end = false;
    while(!end)
    {
        auto currentTicks = SDL_GetTicks();
        float dt = (currentTicks - prevTicks) / deltaTimeConstant;
        prevTicks = currentTicks;

        end = processEvents(state, dt);

        updateGameplay(state, dt);
        display(screen, state);
    }

    scope(exit) SDL_Quit();
    SDL_GL_DeleteContext(context);
}
