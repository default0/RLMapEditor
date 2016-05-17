struct EnemyType {
    string name;
    string[] tierNames;
    int typeId;
}
EnemyType[int] enemyTypes;
enum EnemyTier : ubyte {
    basic = 0,
    advanced = 1,
    expert = 2,
    miniboss = 3
}
struct MapEnemySave {
    int x, y;
    string name;
    EnemyType enemyType;
    EnemyTier enemyTier;
}
struct MapRoomSave {
    align(1) {
        int poolIndex;
        ubyte levelType;
        int x;
        int y;
        ubyte red;
        ubyte green;
        ubyte blue;
    }
    
    @property int tileX() {
        return x / 1320;
    }
    @property int tileY() {
        return y / 720;
    }
}
uint reverseBytes(uint val) {
    // bits 0-8 => 24-32
    // bits 8-16 => 16-24
    // bits 16-24 => 8-16
    // bits 24-32 => 0-8
    return        ((val & 0xFF) << 24) |
                  ((val & 0xFF00) << 8) |
                  ((val & 0xFF0000) >> 8) |
                  ((val & 0xFF000000) >> 24);
}
struct MapSave {
    int mapSize;
    MapRoomSave[] roomData;
    int numEnemies;
    ubyte[] enemyTypes;
    ubyte[] enemyTiers;
    
    MapEnemySave[] enemies;
    
    void writeTo(string path) {
        import cerealed, std.file;
        
        auto cerealiser = Cerealiser();
        cerealiser ~= reverseBytes(mapSize);
        foreach(ref room; roomData) {
            cerealiser ~= reverseBytes(room.poolIndex);
            cerealiser ~= room.levelType;
            cerealiser ~= reverseBytes(room.x);
            cerealiser ~= reverseBytes(room.y);
            cerealiser ~= room.red;
            cerealiser ~= room.green;
            cerealiser ~= room.blue;
        }
        cerealiser ~= reverseBytes(cast(uint)enemies.length);
        foreach(ref enemy; enemies) {
            cerealiser ~= cast(ubyte)enemy.enemyType.typeId;
        }
        foreach(ref enemy; enemies) {
            cerealiser ~= cast(ubyte)enemy.enemyTier;
        }
        write(path, cerealiser.bytes);
    }
}

struct MapDataSave {
    int numDiscoveredRooms;
    bool[] discoveredRooms;
    
    int numCompletedBonusRooms;
    bool[] completedBonusRooms;
    int[] bonusRoomIds;
    
    int numChestTypes;
    ubyte[] chestTypes;
    
    int numOpenedChests;
    bool[] openedChests;
    
    int numUnlockedFairyChests;
    bool[] unlockedFairyChests;
    
    int numKilledEnemies;
    bool[] killedEnemies;
    
    int numDestroyedBreakables;
    bool[] destroyedBreakables;
}

struct Enemy {
    int x, y;
    string name;
}
struct RoomData {
    string name;
    int x, y;
    int width, height;
    bool castlePool, forestPool, towerPool, dungeonPool;
    
    RoomObj[] objects;
    Enemy[] enemies;
    DoorObj[] doors;
    
    @property int tileWidth() {
        return width / 1320;
    }
    @property int tileHeight() {
        return height / 720;
    }
    
    void drawTo(MapRoomSave room, DrawBuf buf, Rect rc, bool isSelected, float zoom) {
        if(!isSelected) {
            if(name == "Bonus") {
                buf.fillRect(rc, 0x00FF00);
            }
            else if(name == "Secret") {
                buf.fillRect(rc, 0xFF00FF);
            }
            else if(name == "EntranceBoss") {
                buf.fillRect(rc, 0xFF0000);
            }
            else {
                buf.fillRect(rc, 0xFFFFFF);
            }
        }
        else {
            buf.fillRect(rc, 0xFFFF00);
        }
        uint objColor;
        switch(room.levelType) {
            case 1:
                objColor = 0x808080;
                break;
            case 2:
                objColor = 0x008000;
                break;
            case 3:
                objColor = 0x800000;
                break;
            case 4:
                objColor = 0x000080;
                break;
            default:
                objColor = 0x0000FF;
                break;
        } 
        foreach(obj; objects) {
            auto proportionalX = cast(double)(obj.x - x) / cast(double)width;
            auto proportionalY = cast(double)(obj.y - y) / cast(double)height;
            auto proportionalWidth = cast(double)obj.width / cast(double)width;
            auto proportionalHeight = cast(double)obj.height / cast(double)height;
            
            proportionalX = rc.left + (proportionalX * rc.width);
            proportionalY = rc.top + (proportionalY * rc.height);
            proportionalWidth = proportionalWidth * rc.width;
            proportionalHeight = proportionalHeight * rc.height;
            buf.fillRect(
                Rect(
                    cast(int)proportionalX,
                    cast(int)proportionalY,
                    cast(int)proportionalX + cast(int)proportionalWidth,
                    cast(int)proportionalY + cast(int)proportionalHeight
                ),
                objColor
            );
        }
    }
    
    private static string[string] doorMappings;
    static this() {
        doorMappings = [
            "Left": "Right",
            "Right": "Left",
            "!Left": "!Right",
            "!Right": "!Left",
            "!RightTop": "!LeftTop",
            "!RightBottom": "!LeftBottom",
            "!LeftTop": "!RightTop",
            "!LeftBottom": "!RightBottom",
            "RightTop": "LeftTop",
            "RightBottom": "LeftBottom",
            "LeftTop": "RightTop",
            "LeftBottom": "RightBottom",
            "!BottomLeft": "!BottomRight",
            "!BottomRight": "!BottomLeft",
            "!TopLeft": "!TopRight",
            "!TopRight": "!TopLeft",
            "BottomLeft": "BottomRight",
            "BottomRight": "BottomLeft",
            "TopLeft": "TopRight",
            "TopRight": "TopLeft"
        ];
    }
    RoomData reverse() {
        auto clone = RoomData(name, x, y, width, height, castlePool, forestPool, towerPool, dungeonPool);
        clone.enemies = enemies.dup;
        clone.objects = objects.dup;
        clone.doors = doors.dup;
        foreach(ref clonedObj; clone.objects) {
            // do the reversal I guess!
            clonedObj.x = width - (clonedObj.x - x) - clonedObj.width + x;
        }
        foreach(ref enemy; clone.enemies) {
            enemy.x = width - (enemy.x - x) + x;
            if(enemy.name in doorMappings) {
                enemy.name = doorMappings[enemy.name];
            }
        }
        foreach(ref door; clone.doors) {
            // only Left <=> Right are relevant, but works as well, so we gonna use it :o)
            if(door.pos in doorMappings) {
                door.pos = doorMappings[door.pos];
            }
            door.x = width - (door.x - x) + x;
        }
        return clone;
    }
}
struct DoorObj {
    int x, y;
    string pos;
}
struct RoomObj {
    int x, y;
    int width, height;
}

enum ELevelType {
    castle,
    forest,
    tower,
    dungeon
}
import std.stdio;
import dlangui;
import derelict.opengl3.gl3;
import derelict.opengl3.gl;
import dlangui.graphics.glsupport;
import dlangui.graphics.gldrawbuf;

mixin APP_ENTRY_POINT;

extern(C) int UIAppMain(string[] args) {

    try
    {
        auto baseMapPath = "/home/gregory/roguelegacy/Content/Levels/";
        auto mapPaths = [
            baseMapPath ~ "Map_1x1.xml",
            baseMapPath ~ "Map_1x2.xml",
            baseMapPath ~ "Map_1x3.xml",
            baseMapPath ~ "Map_2x1.xml",
            baseMapPath ~ "Map_2x2.xml",
            baseMapPath ~ "Map_2x3.xml",
            baseMapPath ~ "Map_3x1.xml",
            baseMapPath ~ "Map_3x2.xml",
            baseMapPath ~ "Map_Special.xml",
            baseMapPath ~ "Map_DLC1.xml"
        ];
        
        enemyTypes = [
            1: EnemyType(
                "Ball and Chain Knight",
                ["Chaintor", "Chaintex", "Chaintus"],
                1
            ),
            2: EnemyType(
                "Blob",
                ["Bloob", "Bloobite", "Bloobasaurus Rex"],
                2
            ),
            3: EnemyType(
                "Flying Spikeball",
                ["Spiketor", "Spiketex", "Spiketus"],
                3
            ),
            5: EnemyType(
                "Earth Wizard",
                ["Earthsor", "Gravisor", "Terrasor"],
                5
            ),
            6: EnemyType(
                "Eyeball",
                ["Scout", "Pupil", "Visionary"],
                6
            ),
            7: EnemyType(
                "Floating Skull",
                ["Fury", "Rage", "Wrath"],
                7
            ),
            8: EnemyType(
                "Flying Fireball",
                ["Charite", "Pyrite", "Infernite"],
                8
            ),
            9: EnemyType(
                "Firewizard",
                ["Flamelock", "Blazelock", "Sollock"],
                9
            ),
            10: EnemyType(
                "Horse",
                ["Headless Horse", "Dark Stallion", "Night Mare"],
                10
            ),
            11: EnemyType(
                "Ice Wizard",
                ["Frosten", "Icen", "Glacien"],
                11
            ),
            12: EnemyType(
                "Corrupt Knight",
                ["Corrupt Knight", "Corrupt Vanguard", "Corrupt Lord", "Botis"],
                12
            ),
            13: EnemyType(
                "Ninja",
                ["Ninjo", "Ninpo", "Ninpojo"],
                13
            ),
            14: EnemyType(
                "Shield Knight",
                ["Tall Guard", "Hulk Guard", "Tower Guard"],
                14
            ),
            15: EnemyType(
                "Skeleton",
                ["Skeleton", "Mr Bones", "McRib", "Berith"],
                15
            ),
            16: EnemyType(
                "Sword Knight",
                ["Gray Knight", "Gray Baron", "Graydiator"],
                16
            ),
            17: EnemyType(
                "Wall Turret",
                ["Wall Turret"],
                17
            ),
            19: EnemyType(
                "Wolf",
                ["Warg", "Wargen", "Wargenflorgen"],
                19
            ),
            20: EnemyType(
                "Zombie",
                ["Zombie", "Zomboner", "Zombishnu"],
                20
            ),
            21: EnemyType(
                "Spike Trap",
                ["Spike Trap"],
                21
            ),
            22: EnemyType(
                "Plant",
                ["Bud", "Plantite", "Flowermon", "Focalor"],
                22
            ),
            23: EnemyType(
                "Energon",
                ["Energon", "Mastertron", "Voltron"],
                23
            ),
            24: EnemyType(
                "Spark",
                ["Sparky", "Mr. Spark", "Grandpa Spark"],
                24
            ),
            25: EnemyType(
                "Archer",
                ["Archer", "Ranger", "Sniper"],
                25
            ),
            26: EnemyType(
                "Chicken",
                ["Kentucky", "Fried", "Chicken"],
                26
            ),
            28: EnemyType(
                "Guardbox",
                ["GuardBox", "GuardBox XL", "GuardBox 2000"],
                28
            ),
            29: EnemyType(
                "Johannes",
                ["Johannes", "The Fountain", "Johannes"],
                29
            ),
            30: EnemyType(
                "Training Dummy",
                ["Training Dummy", "Training Dummy", "Training Dummy"],
                30
            ),
            31: EnemyType(
                "Plonky",
                ["Plinky", "Planky", "Plonky"],
                31
            ),
            32: EnemyType(
                "Portrait",
                ["Doomvas", "Doomtrait", "Doomscape", "Sallos"],
                32
            ),
            33: EnemyType(
                "Mimic",
                ["Mimic", "Mimicant", "Mimicrunch"],
                33
            )
        ];
    
        import std.file, std.exception, std.xml;
        foreach(mapPath; mapPaths) {
            import std.algorithm : canFind;
            readRooms(mapPath, canFind(mapPath, "DLC")); // Map_DLC1.xml is the last entry, and is a DLC map, which is what we need as second arg
        }
    
        sequencedRooms = buildSequencedRoomList();
    
        return showWindow();
    }
    catch(Throwable t)
    {
        writeln(t);
        readln();
    }
    assert(0);
}

RoomData[] sequencedRooms;
auto getRoomByPoolIndex(int poolIndex) {
    if(poolIndex < 10000) {
        if(poolIndex >= sequencedRooms.length) {
            writeln("No room with poolIndex ", poolIndex);
            return RoomData();
        }
        return sequencedRooms[poolIndex];
    }
    else if(poolIndex < 20000) {
        if(poolIndex - 10000 >= dlcCastlePool.length) {
            writeln("No room with poolIndex ", poolIndex);
            return RoomData();
        }
        return dlcCastlePool[poolIndex - 10000];
    }
    else if(poolIndex < 30000) {
        if(poolIndex - 20000 >= dlcForestPool.length) {
            writeln("No room with poolIndex ", poolIndex);
            return RoomData();
        }
        return dlcForestPool[poolIndex - 20000];
    }
    else if(poolIndex < 40000) {
        if(poolIndex - 30000 >= dlcTowerPool.length) {
            writeln("No room with poolIndex ", poolIndex);
            return RoomData();
        }
        return dlcTowerPool[poolIndex - 30000];
    }
    else {
        if(poolIndex - 40000 >= dlcDungeonPool.length) {
            writeln("No room with poolIndex ", poolIndex);
            return RoomData();
        }
        return dlcDungeonPool[poolIndex - 40000];
    }
}

MapSave mapSave;
MapDataSave mapDataSave;
enum MapFilePath = "RogueLegacyMap.rcdat";
enum MapDataFilePath = "RogueLegacyMapDat.rcdat";
auto showWindow() {
    if(!Platform.instance) {
        writeln("Cannot create window - platform is null.");
    }

    class EditorWidget : VerticalLayout {
        int cameraX;
        int cameraY;
        
        float zoom;
        
        bool upDown;
        bool downDown;
        bool leftDown;
        bool rightDown;
        
        bool isDragging;
        int dragStartMouseX;
        int dragStartMouseY;
        int dragStartCamX;
        int dragStartCamY;
        
        MapRoomSave* selectedRoom;
        MapEnemySave* selectedEnemy;
        TableLayout propertiesGrid;
        
        string profilePath;
        bool hasEdited;
        
        enum ObjType {
            room,
            enemy
        }
        struct ColRect {
            Rect rect;
            ObjType type;
            void* objPtr;
        }
        ColRect[] colRects;
        
        this() {
            super("OpenGLView");
            layoutWidth = FILL_PARENT;
            layoutHeight = FILL_PARENT;
            alignment = Align.Center;
            
            zoom = 1f;
            cameraX = 0;
            cameraY = 0;
            
            
            // add some UI on top of OpenGL drawable
            auto w = parseML(q{
                VerticalLayout {
                    layoutWidth: fill
                    layoutHeight: fill
                    
                    HorizontalLayout {
                        alignment: center
                        layoutWidth: fill; layoutHeight: fill
                        // background for window - tiled texture
                        CanvasWidget {
                            // child widget - will draw using OpenGL here
                            id: canvas
                            margins: 1
                            padding: 1
                            layoutWidth: fill
                            layoutHeight: fill
                        }
                        VerticalLayout {
                            alignment: right
                            layoutWidth: 20%
                            layoutHeight: fill
                            backgroundColor: 0x666666
                            TextWidget { text: "Properties"; textColor: 0xFFFFFF }
                            TableLayout {
                                id: "propertiesGrid"
                                colCount: 1
                                backgroundColor: 0x777777
                                textColor: 0xFFFFFF
                            }
                        }
                    }
                }
            });
            enum ACTION_FILE_OPEN = 100;
            enum ACTION_FILE_SAVE = 101;
            auto mmItems = new MenuItem();
            MenuItem fileItem = new MenuItem(new Action(1, "File"d));
            Action[] actions = [
                new Action(ACTION_FILE_OPEN, "Open"d, null, KeyCode.KEY_O, KeyFlag.Control),
                new Action(ACTION_FILE_SAVE, "Save"d, null, KeyCode.KEY_S, KeyFlag.Control)
            ];
            fileItem.add(actions[0]);
            fileItem.add(actions[1]);
            mmItems.add(fileItem);
            auto mm = new MainMenu(mmItems);
            void handleAction(const Action action) {
                import dlangui.dialogs.dialog;
                import dlangui.dialogs.filedlg;
                import std.path, std.file;
                switch(action.id) {
                    case ACTION_FILE_OPEN:
                        auto dlg = new FileDialog(UIString("Open File"d), window, null, FileDialogFlag.SelectDirectory | FileDialogFlag.FileMustExist);
                        dlg.show();
                        dlg.dialogResult.connect(delegate(Dialog dialog, const Action result) {
                            
                            auto mapFilePath = buildPath(dlg.path, "RogueLegacyMap.rcdat");
                            auto mapDataFilePath = buildPath(dlg.path, "RogueLegacyMapDat.rcdat");
                            if(!exists(mapFilePath)) {
                                window.showMessageBox(UIString("Error"d), UIString("There is no RogueLegacyMap.rcdat file in the selected directory."d));
                                return;
                            }
                            if(!exists(mapDataFilePath)) {
                                window.showMessageBox(UIString("Error"d), UIString("There is no RogueLegacyMapDat.rcdat file in the selected directory."d));
                                return;
                            }
                            
                            profilePath = dlg.path;
        
                            mapSave = readMapSave(mapFilePath, sequencedRooms);
                            mapDataSave = readMapDataSave(mapDataFilePath);
                            
                            selectObj(null);
                            zoom = 1f;
                            cameraX = 0;
                            cameraY = 0;
                            colRects = [];
                            
                            import std.string;
                            
                            setEdited(false);
                            window.windowCaption = profilePath[profilePath.lastIndexOfAny("/\\") + 1 .. $].to!dstring;
                        });
                        break;
                    case ACTION_FILE_SAVE:
                        mapSave.writeTo(buildPath(profilePath, "RogueLegacyMap.rcdat"));
                        //mapDataSave.writeTo(buildPath(profilePath, "RogueLegacyMapDat.rcdat"));
                    
                        setEdited(false);
                        break;
                    default:
                        break;
                }
            }
            mm.menuItemClick = delegate(MenuItem item) {
                handleAction(item.action);
                return true;
            };
            auto other = w.removeChild(0);
            w.addChild(mm);
            w.addChild(other);
            
            // assign OpenGL drawable to child widget background
            auto canvas = w.childById!CanvasWidget("canvas");
            propertiesGrid = w.childById!TableLayout("propertiesGrid");
            mouseEvent.connect(delegate(Widget widget, MouseEvent event) {
                if(event.action == MouseAction.Wheel) {
                    zoom += event.wheelDelta * 0.1f;
                    return true;
                }
                if(event.action == MouseAction.ButtonDown || event.action == MouseAction.ButtonUp) {
                    if(event.lbutton.isDown) {
                        int tileWidth = cast(int)(26f * zoom);
                        int tileHeight = cast(int)(14f * zoom);
                        
                        import std.algorithm : reverse;
                        foreach_reverse(ref colRect; colRects) {
                            if(event.x >= colRect.rect.left && event.x <= colRect.rect.right) {
                                if(event.y >= colRect.rect.top && event.y <= colRect.rect.bottom) {
                                    final switch(colRect.type) {
                                        case ObjType.room:
                                            selectObj(cast(MapRoomSave*)colRect.objPtr);
                                            break;
                                        case ObjType.enemy:
                                            selectObj(cast(MapEnemySave*)colRect.objPtr);
                                            break;
                                    }
                                    return true;
                                }
                            }
                        }
                    }
                    bool wasDragging = isDragging;
                    isDragging = event.lbutton.isDown;
                    if(isDragging) {
                        dragStartMouseX = event.x;
                        dragStartMouseY = event.y;
                        dragStartCamX = cameraX;
                        dragStartCamY = cameraY;
                    }
                    else if(wasDragging) {
                        // we clicked & released, but did not drag the camera and did not click on a room => deselect
                        if(dragStartCamX == cameraX && dragStartCamY == cameraY) {
                            selectObj(null);
                        }
                    }
                }
                if(event.action == MouseAction.Move && isDragging) {
                    cameraX = dragStartCamX + (event.x - dragStartMouseX);
                    cameraY = dragStartCamY + (event.y - dragStartMouseY);
                }
                
                return true;
            });
            keyEvent.connect(delegate(Widget widget, KeyEvent event) {
                // 37, 38, 39, 40
                // left, up, right, down
                // 65, 87, 68, 83
                // a, w, d, s
                bool targetValue;
                if(event.action == KeyAction.KeyDown) {
                    targetValue = true;
                }
                else if(event.action == KeyAction.KeyUp) {
                    targetValue = false;
                }
                
                if(event.action == KeyAction.KeyDown) {
                    auto flags = cast(KeyFlag)(event.flags & ~(KeyFlag.LControl & ~KeyFlag.Control));
                    flags = cast(KeyFlag)(flags & ~(KeyFlag.RControl & ~KeyFlag.Control));
                    //auto result = mm.acceleratorMap.findByKey(event.keyCode, event.flags);
                    auto act = mm.findKeyAction(event.keyCode, flags);
                    if(act) {
                        handleAction(act);
                        return true;
                    }
                }
                
                switch(event.keyCode) {
                    case 37:
                    case 65:
                        leftDown = targetValue;
                        return true;
                    case 38:
                    case 87:
                        upDown = targetValue;
                        return true;
                    case 39:
                    case 68:
                        rightDown = targetValue;
                        return true;
                    case 40:
                    case 83:
                        downDown = targetValue;
                        return true;
                    default:
                        return false;
                }
            });
            canvas.onDrawListener = delegate(CanvasWidget canvas, DrawBuf buf, Rect rc) {
                buf.fill(0x000000);
                int x = rc.left + cameraX;
                int y = rc.top + cameraY;
                int tileWidth = cast(int)(26f * zoom);
                int tileHeight = cast(int)(14f * zoom);
                
                int objIndex = 0;
                foreach(ref room; mapSave.roomData) {
                    bool isSelected = false;
                    if(&room == selectedRoom)
                        isSelected = true;
                        
                    RoomData roomData = getRoomByPoolIndex(room.poolIndex);
                    auto gridXHigh = room.tileX + roomData.tileWidth;
                    auto gridYHigh = room.tileY + roomData.tileHeight;
        
                    enum offset = 2;
                    Rect drawRect = Rect(
                        x + room.tileX * tileWidth + offset,
                        y + room.tileY * tileHeight + offset,
                        x + gridXHigh * tileWidth - offset,
                        y + gridYHigh * tileHeight - offset
                    );
                    if(colRects.length <= objIndex) {
                        colRects ~= ColRect(drawRect, ObjType.room, &room);
                    }
                    else {
                        colRects[objIndex].rect = drawRect;
                    }
                    
                    roomData.drawTo(
                        room,
                        buf,
                        drawRect,
                        isSelected,
                        zoom
                    );
                    ++objIndex;
                }
                foreach(ref enemy; mapSave.enemies) {
                    auto enemyX = cast(int)(cast(double)enemy.x / 1320.0 * tileWidth);
                    auto enemyY = cast(int)(cast(double)enemy.y / 720.0 * tileHeight);
                    
                    Rect drawRect = Rect(
                        x + enemyX,
                        y + enemyY,
                        x + enemyX + cast(int)(zoom * 2),
                        y + enemyY + cast(int)(zoom * 2)
                    );
                    if(colRects.length <= objIndex) {
                        colRects ~= ColRect(drawRect, ObjType.enemy, &enemy);
                    }
                    else {
                        colRects[objIndex].rect = drawRect;
                    }
                    
                    
                    buf.fillRect(
                        drawRect,
                        enemy.enemyTier == EnemyTier.miniboss ? 0xFFFF00 : 0xFF0000
                    );
                    ++objIndex;
                }
            };
            
            addChild(w);
        }
        
        void setEdited(bool edited) {
            bool wasEditedBefore = hasEdited;
            hasEdited = edited;
            if(edited && !wasEditedBefore) {
                window.windowCaption = window.windowCaption ~ "*"d;
            }
            else if(!edited && wasEditedBefore) {
                window.windowCaption = window.windowCaption[0 .. $-1];
            }
        }

        /// returns true is widget is being animated - need to call animate() and redraw
        @property override bool animating() { return true; }
        /// animates window; interval is time left from previous draw, in hnsecs (1/10000000 of second)
        override void animate(long interval) {
            if(!isDragging) {
                if(upDown) {
                    cameraY += 10;
                }
                if(downDown) {
                    cameraY -= 10;
                }
                if(leftDown) {
                    cameraX += 10;
                }
                if(rightDown) {
                    cameraX -= 10;
                }
            }
            invalidate();
        }
        
        void selectObj(T = void)(T* objPtr) {
            selectedRoom = null;
            selectedEnemy = null;
            propertiesGrid.removeAllChildren(); // clear whatever the old selection was
            if(objPtr is null)
                return;
                
            static if(is(T == MapRoomSave)) {
                selectedRoom = objPtr;
            
                // show/update room properties here
                auto text = new TextWidget();
                text.text = "Room Name: " ~ getRoomByPoolIndex((*objPtr).poolIndex).name.to!dstring;
                text.textColor = propertiesGrid.textColor;
                propertiesGrid.addChild(text);
                
                text = new TextWidget();
                text.text = "Room Id: " ~ (*objPtr).poolIndex.to!dstring;
                text.textColor = propertiesGrid.textColor;
                propertiesGrid.addChild(text);
                
                text = new TextWidget();
                text.text = "X: " ~ (*objPtr).x.to!dstring;
                text.textColor = propertiesGrid.textColor;
                propertiesGrid.addChild(text);
                
                text = new TextWidget();
                text.text = "Y: " ~ (*objPtr).y.to!dstring;
                text.textColor = propertiesGrid.textColor;
                propertiesGrid.addChild(text);
            }
            else static if(is(T == MapEnemySave)) {
                import std.algorithm;
                import std.array;
                import std.range;
                import std.functional;
                selectedEnemy = objPtr;
                
                TextWidget enemyNameText = new TextWidget();
                writeln("Displaying details for a tier ", (*objPtr).enemyTier, " type ", (*objPtr).enemyType.typeId, " enemy.");
                enemyNameText.text = "Enemy Name: "d ~ (*objPtr).enemyType.tierNames[(*objPtr).enemyTier].to!dstring;
                enemyNameText.textColor = propertiesGrid.textColor;
                // do not add enemyNameText here because we want to display it below the type and tier combo boxes
                
                HorizontalLayout enemyTier = new HorizontalLayout();
                TextWidget text = new TextWidget();
                text.text = "Enemy Tier";
                text.textColor = propertiesGrid.textColor;
                enemyTier.addChild(text);
                
                ComboBox enemyTierBox = new ComboBox();
                auto tiers = ["Basic"d, "Advanced"d, "Expert"d, "Miniboss"d];
                enemyTierBox.items = tiers[0 .. (*objPtr).enemyType.tierNames.length];
                enemyTierBox.textColor = propertiesGrid.textColor;
                enemyTierBox.selectedItemIndex = (*objPtr).enemyTier;
                enemyTierBox.itemClick.connect(delegate(Widget source, int itemIndex) {
                    (*objPtr).enemyTier = cast(EnemyTier)itemIndex;
                    setEdited(true);
                    
                    enemyNameText.text = "Enemy Name: "d ~ (*objPtr).enemyType.tierNames[(*objPtr).enemyTier].to!dstring;
                    return true;
                });
                enemyTier.addChild(enemyTierBox);
                
                // do not add enemyTier here because we want enemyType to be above it
                
                HorizontalLayout enemyType = new HorizontalLayout();
                text = new TextWidget();
                text.text = "Enemy Type";
                text.textColor = propertiesGrid.textColor;
                enemyType.addChild(text);
                
                ComboBox enemyTypeBox = new ComboBox();
                auto sortedEnemyTypes = enemyTypes.values.sort!((a, b) => a.typeId < b.typeId);
                enemyTypeBox.items = enemyTypes.values.sort!((a, b) => a.typeId < b.typeId).map!(x => "#" ~ x.typeId.to!dstring ~ " " ~ x.name.to!dstring).array;
                enemyTypeBox.textColor = propertiesGrid.textColor;
                auto otherVal = (*objPtr).enemyType.typeId;
                enemyTypeBox.selectedItemIndex = cast(int)count!(x => x < otherVal)(enemyTypes.keys);
                enemyTypeBox.itemClick.connect(delegate(Widget source, int itemIndex) {
                    auto oldIndex = enemyTierBox.selectedItemIndex;
                    (*objPtr).enemyType = sortedEnemyTypes[itemIndex];
                    setEdited(true);
                    
                    enemyTierBox.items = tiers[0 .. sortedEnemyTypes[itemIndex].tierNames.length];
                    enemyTierBox.selectedItemIndex = oldIndex >= enemyTierBox.items.length ? enemyTierBox.items.length - 1 : oldIndex;
                    
                    enemyNameText.text = "Enemy Name: "d ~ (*objPtr).enemyType.tierNames[(*objPtr).enemyTier].to!dstring;
                    return true;
                });
                enemyType.addChild(enemyTypeBox);
                
                propertiesGrid.addChild(enemyType);
                propertiesGrid.addChild(enemyTier); // add enemyTier here because we want enemyType to be above it
                
                propertiesGrid.addChild(enemyNameText); // add name-txt here because we want type and tier above it
                
                text = new TextWidget();
                text.text = "Enemy Object Name: "d ~ (*objPtr).name.to!dstring;
                text.textColor = propertiesGrid.textColor;
                propertiesGrid.addChild(text);
                
                text = new TextWidget();
                text.text = "X: " ~ (*objPtr).x.to!dstring;
                text.textColor = propertiesGrid.textColor;
                propertiesGrid.addChild(text);
                
                text = new TextWidget();
                text.text = "Y: " ~ (*objPtr).y.to!dstring;
                text.textColor = propertiesGrid.textColor;
                propertiesGrid.addChild(text);
            }
            else static if(is(T == void)) {
                assert(objPtr is null, "If you supply type void, the given pointer MUST be null.");
            }
            else {
                static assert(0, "This method only accepts types " ~ MapRoomSave.stringof ~ ", " ~ MapEnemySave.stringof ~ " and " ~ void.stringof);
            }
        }
    }
    Window window = Platform.instance.createWindow("Rogue Legacy Map Editor", null);
    window.mainWidget = new EditorWidget();
    
    /*auto sgw = window.mainWidget.childById!StringGridWidget("sgw");
    sgw.resize(10, 10);
    sgw.setCellText(0, 0, "Test");
    // grid is 1320 x 720
    foreach(room; mapSave.roomData) {
        auto gridXLow = room.x / 1320;
        auto gridYLow = room.y / 720;               
        
        RoomData roomData = getRoomByPoolIndex(room.poolIndex);
        if(roomData.name is null) {
            // error occured and poolIndex is bad.
            writeln("Room = ", room);
        }
        auto gridXHigh = gridXLow + roomData.width / 1320;
        auto gridYHigh = gridYLow + roomData.height / 720;
        
        foreach(gridX; gridXLow .. gridXHigh) {
            foreach(gridY; gridYLow .. gridYHigh) {
                if(gridX > -1 && gridX < 10 && gridY > -1 && gridY < 10) {
                    sgw.setCellText(gridX, gridY, "ROOM " ~ room.poolIndex.to!dstring);
                }
            }
        }
    }*/
    
    window.show();
    
    return Platform.instance.enterMessageLoop();
}

RoomData[][4][4] castlePool;
RoomData[][4][4] forestPool;
RoomData[][4][4] towerPool;
RoomData[][4][4] dungeonPool;
RoomData[] dlcCastlePool;
RoomData[] dlcForestPool;
RoomData[] dlcTowerPool;
RoomData[] dlcDungeonPool;
RoomData[] bossRooms;

RoomData startingRoom;

RoomData linkerCastleRoom;
RoomData linkerForestRoom;
RoomData linkerTowerRoom;
RoomData linkerDungeonRoom;

RoomData bossCastleEntranceRoom;
RoomData bossForestEntranceRoom;
RoomData bossTowerEntranceRoom;
RoomData bossDungeonEntranceRoom;

RoomData castleEntranceRoom;
RoomData compassRoom;

RoomData[] secretCastleRooms;
RoomData[] secretForestRooms;
RoomData[] secretTowerRooms;
RoomData[] secretDungeonRooms;

RoomData[] bonusCastleRooms;
RoomData[] bonusForestRooms;
RoomData[] bonusTowerRooms;
RoomData[] bonusDungeonRooms;

RoomData tutorialRoom;
RoomData throneRoom;
RoomData endingRoom;

RoomData[] challengeBossRooms;

RoomData[] buildSequencedRoomList() {
    RoomData[] sequencedRoomList;
    sequencedRoomList ~= startingRoom;
    sequencedRoomList ~= linkerCastleRoom;
    sequencedRoomList ~= linkerTowerRoom;
    sequencedRoomList ~= linkerDungeonRoom;
    sequencedRoomList ~= linkerForestRoom;
    sequencedRoomList ~= bossCastleEntranceRoom;
    sequencedRoomList ~= bossTowerEntranceRoom;
    sequencedRoomList ~= bossDungeonEntranceRoom;
    sequencedRoomList ~= bossForestEntranceRoom;
    sequencedRoomList ~= castleEntranceRoom;
    
    alias addPool = (pool) {
        for(int x = 0; x < 4; ++x) {
            for(int y = 0; y < 4; ++y) {
                foreach(roomData; pool[x][y]) {
                    sequencedRoomList ~= roomData;
                }
            }
        }
    };
    addPool(castlePool);
    addPool(dungeonPool);
    addPool(towerPool);
    addPool(forestPool);
    
    alias addArray = (array) {
        foreach(roomData; array) {
            sequencedRoomList ~= roomData;
        }
    };
    addArray(secretCastleRooms);
    addArray(secretTowerRooms);
    addArray(secretDungeonRooms);
    addArray(secretForestRooms);
    
    addArray(bonusCastleRooms);
    addArray(bonusTowerRooms);
    addArray(bonusDungeonRooms);
    addArray(bonusForestRooms);
    
    addArray(challengeBossRooms);
    
    sequencedRoomList ~= compassRoom;
    return sequencedRoomList;
}
auto readRooms(string filePath, bool isDlc) {
    import std.xml;
    import std.array, std.conv;
    import std.file : readText;
    import std.algorithm.searching : canFind;
    import std.string : indexOf;
    
    Document document = new Document(readText(filePath));
    auto documentRooms = appender!(RoomData[]);
    foreach(element; document.elements) {
        if(element.tag.name != "RoomObject")
            continue;
        
        auto tagMetadata = element.tag.attr;
        auto room = RoomData();
        room.x = to!int(tagMetadata["X"]);
        room.y = to!int(tagMetadata["Y"]);
        room.width = to!int(tagMetadata["Width"]);
        room.height = to!int(tagMetadata["Height"]);
        room.castlePool = to!bool(tagMetadata["CastlePool"]);
        room.forestPool = to!bool(tagMetadata["GardenPool"]);
        room.towerPool = to!bool(tagMetadata["TowerPool"]);
        room.dungeonPool = to!bool(tagMetadata["DungeonPool"]);
        room.name = tagMetadata["Name"];
        foreach(roomElement; element.elements) {
            if(roomElement.tag.name != "GameObject")
                continue;
            
            auto objectMetadata = roomElement.tag.attr;
            switch(objectMetadata["Type"]) {
                case "CollHullObj":
                    auto roomObj = RoomObj();
                    roomObj.x = cast(int)to!float(objectMetadata["X"]);
                    roomObj.y = cast(int)to!float(objectMetadata["Y"]);
                    roomObj.width = cast(int)to!float(objectMetadata["Width"]);
                    roomObj.height = cast(int)to!float(objectMetadata["Height"]);
                    room.objects ~= roomObj;
                    break;
                case "DoorObj":
                    auto door = DoorObj();
                    door.x = cast(int)to!float(objectMetadata["X"]);
                    door.y = cast(int)to!float(objectMetadata["Y"]);
                    door.pos = objectMetadata["DoorPos"];
                    room.doors ~= door;
                    break;
                case "EnemyOrbObj":
                    if(objectMetadata["IsWaypoint"] == "True") {
                        continue;
                    }
                    
                    auto enemy = Enemy();
                    enemy.x = cast(int)to!float(objectMetadata["X"]);
                    enemy.y = cast(int)to!float(objectMetadata["Y"]);
                    enemy.name = objectMetadata["Name"];
                    room.enemies ~= enemy;
                    break;
                case "EnemyObj":
                    if(objectMetadata["Procedural"] == "False")
                        continue;
                        
                    auto enemy = Enemy();
                    enemy.x = cast(int)to!float(objectMetadata["X"]);
                    enemy.y = cast(int)to!float(objectMetadata["Y"]);
                    enemy.name = objectMetadata["Name"];
                    room.enemies ~= enemy;
                    break;
                default:
                    continue;
            }
        }
        documentRooms.put(room);
        
        if(room.x < 10000.0 && room.name != "Boss" && room.name != "ChallengeBoss") {
            // finish this stuff up with logic emulating StoreSpecialRoom
            // after that we can figure out pool indices of rooms
            // when thats done we can go ahead and draw a map and compare it to the layout of the actually explored
            // ingame map.
            if(!canFind(room.name, "DEBUG_ROOM")) {
                if(room.castlePool) {
                    addToPool(room, castlePool, dlcCastlePool, isDlc);
                    addSpecialRoom(room, ELevelType.castle);
                }
                
                if(room.forestPool) {
                    addToPool(room, forestPool, dlcForestPool, isDlc);
                    addSpecialRoom(room, ELevelType.forest);
                }
                
                if(room.towerPool) {
                    addToPool(room, towerPool, dlcTowerPool, isDlc);
                    addSpecialRoom(room, ELevelType.tower);
                }
                
                if(room.dungeonPool) {
                    addToPool(room, dungeonPool, dlcDungeonPool, isDlc);
                    addSpecialRoom(room, ELevelType.dungeon);
                }
            }
            else {
                // do debug room stuff
                room.name = room.name[room.name.indexOf("DEBUG_ROOM") + "DEBUG_ROOM".length .. $];
                addSpecialRoom(room, ELevelType.castle);
            }
        }
        else if(room.x < 10000.0 && (room.name == "Boss" || room.name == "ChallengeBoss")) {
            addSpecialRoom(room, ELevelType.castle);
        }
    }
}
auto addSpecialRoom(RoomData room, ELevelType levelType) {
    switch(room.name) {
        case "Start":
            startingRoom = room;
            break;
        case "Linker":
            if(levelType == ELevelType.castle)
                linkerCastleRoom = room;
            else if(levelType == ELevelType.forest)
                linkerForestRoom = room;
            else if(levelType == ELevelType.tower)
                linkerTowerRoom = room;
            else if(levelType == ELevelType.dungeon)
                linkerDungeonRoom = room;
            break;
        case "Boss":
            bossRooms ~= room;
            break;
        case "EntranceBoss":
            if(levelType == ELevelType.castle)
                bossCastleEntranceRoom = room;
            else if(levelType == ELevelType.forest)
                bossForestEntranceRoom = room;
            else if(levelType == ELevelType.tower)
                bossTowerEntranceRoom = room;
            else if(levelType == ELevelType.dungeon)
                bossDungeonEntranceRoom = room;
            break;
        case "CastleEntrance":
            castleEntranceRoom = room;
            break;
        case "Compass":
            compassRoom = room;
            break;
        case "Secret":
            if(levelType == ELevelType.castle) {
                secretCastleRooms ~= room;
                secretCastleRooms ~= room.reverse;
            }
            else if(levelType == ELevelType.forest) {
                secretForestRooms ~= room;
                secretForestRooms ~= room.reverse;
            }
            else if(levelType == ELevelType.tower) {
                secretTowerRooms ~= room;
                secretTowerRooms ~= room.reverse;
            }
            else if(levelType == ELevelType.dungeon) {
                secretDungeonRooms ~= room;
                secretDungeonRooms ~= room.reverse;
            }
            break;
        case "Bonus":
            if(levelType == ELevelType.castle) {
                bonusCastleRooms ~= room;
                bonusCastleRooms ~= room.reverse;
            }
            else if(levelType == ELevelType.forest) {
                bonusForestRooms ~= room;
                bonusForestRooms ~= room.reverse;
            }
            else if(levelType == ELevelType.tower) {
                bonusTowerRooms ~= room;
                bonusTowerRooms ~= room.reverse;
            }
            else if(levelType == ELevelType.dungeon) {
                bonusDungeonRooms ~= room;
                bonusDungeonRooms ~= room.reverse;
            }
            break;
        case "Tutorial":
            tutorialRoom = room;
            break;
        case "Throne":
            throneRoom = room;
            break;
        case "Ending":
            endingRoom = room;
            break;
        case "ChallengeBoss":
            challengeBossRooms ~= room;
            break;
        default:
            return;
    }
}
auto addToPool(RoomData room, ref RoomData[][4][4] roomPool, ref RoomData[] dlcPool, bool isDlc) {
    auto forbiddenRoomNames = [
        "Start", "Linker", "Boss", "EntranceBoss",
        "Secret", "Bonus", "CastleEntrance", "Throne",
        "Tutorial", "Ending", "Compass", "DEBUG_ROOM",
        "ChallengeBoss"
    ];
    import std.algorithm : canFind;
    if(canFind(forbiddenRoomNames, room.name))
        return;
    
    if(!isDlc) {
        roomPool[room.tileWidth][room.tileHeight] ~= room;
        roomPool[room.tileWidth][room.tileHeight] ~= room.reverse;
    }
    else {
        dlcPool ~= room;
        dlcPool ~= room.reverse;
    }
}

auto readMapSave(string filePath, RoomData[] sequencedRooms) {
    import std.exception, std.file;
    auto mapBytes = cast(ubyte[])read(filePath);
    
    MapSave ms = MapSave();
    enforce(mapBytes.length >= 4);
    ms.mapSize = *cast(int*)mapBytes.ptr;
    ms.roomData = cast(MapRoomSave[])(mapBytes[int.sizeof .. ms.mapSize * MapRoomSave.sizeof + int.sizeof]);
    auto enemyDataStart = ms.mapSize * MapRoomSave.sizeof + int.sizeof;
    ms.numEnemies = *cast(int*)mapBytes[enemyDataStart .. $].ptr;
    ms.enemyTypes = mapBytes[enemyDataStart + int.sizeof .. enemyDataStart + int.sizeof + ms.numEnemies];
    ms.enemyTiers = mapBytes[enemyDataStart + int.sizeof + ms.numEnemies .. $];
    enforce(ms.enemyTypes.length == ms.enemyTiers.length);
    
    struct DoorData {
        bool hasTop;
        bool hasTopLeft;
        bool hasTopRight;
        bool hasTopMid;
        
        bool hasBottom;
        bool hasBottomLeft;
        bool hasBottomRight;
        bool hasBottomMid;
        
        bool hasLeft;
        bool hasLeftTop;
        bool hasLeftBottom;
        bool hasLeftMid;
        
        bool hasRight;
        bool hasRightTop;
        bool hasRightBottom;
        bool hasRightMid;
    }
    DoorData getDoorData(ref MapRoomSave room, ref RoomData roomData) {
        DoorData result;
        foreach(ref door; roomData.doors) {
            switch(door.pos) {
                case "Top":
                    result.hasTop = true;
                    if((door.x - roomData.x) == 540)
                        result.hasTopLeft = true;
                    else if((roomData.x + roomData.width - door.x) == 780)
                        result.hasTopRight = true;
                    else if(roomData.tileWidth > 2)
                        result.hasTopMid = true;
                    break;
                case "Bottom":
                    result.hasBottom = true;
                    if((door.x - roomData.x) == 540)
                        result.hasBottomLeft = true;
                    else if((roomData.x + roomData.width - door.x) == 780)
                        result.hasBottomRight = true;
                    else if(roomData.tileWidth > 2)
                        result.hasBottomMid = true;
                    break;
                case "Left":
                    result.hasLeft = true;
                    if((door.y - roomData.y) == 240)
                        result.hasLeftTop = true;
                    else if((roomData.y + roomData.height - door.y) == 480)
                        result.hasLeftBottom = true;
                    else if(roomData.tileHeight > 2)
                        result.hasLeftMid = true;
                    break;
                case "Right":
                    result.hasRight = true;
                    if((door.y - roomData.y) == 240)
                        result.hasRightTop = true;
                    else if((roomData.y + roomData.height - door.y) == 480)
                        result.hasRightBottom = true;
                    else if(roomData.tileHeight > 2)
                        result.hasRightMid = true;
                    break;
                default:
                    break;
            }
        }
        return result;
    }
    void fixInconsistentExits(DoorData* doors) {
        if((*doors).hasTop) {
            if(!(*doors).hasTopLeft && !(*doors).hasTopRight && !(*doors).hasTopMid)
                (*doors).hasTop = false;
        }
        if((*doors).hasBottom) {
            if(!(*doors).hasBottomLeft && !(*doors).hasBottomRight && !(*doors).hasBottomMid)
                (*doors).hasBottom = false;
        }
        if((*doors).hasLeft) {
            if(!(*doors).hasLeftTop && !(*doors).hasLeftBottom && !(*doors).hasLeftMid)
                (*doors).hasLeft = false;
        }
        if((*doors).hasRight) {
            if(!(*doors).hasRightTop && !(*doors).hasRightBottom && !(*doors).hasRightMid)
                (*doors).hasRight = false;
        }
    }
    int getRoomIndex(int tileX, int tileY) {
        int index = 0;
        foreach(ref room; ms.roomData) {
            RoomData roomData = getRoomByPoolIndex(room.poolIndex);
            int tileXEnd = room.tileX + roomData.tileWidth;
            int tileYEnd = room.tileY + roomData.tileHeight;
            if(tileX >= room.tileX && tileY >= room.tileY) {
                if(tileX <= tileXEnd && tileY <= tileYEnd) {
                    return index;
                }
            }
            ++index;
        }
        return -1;
    }
    // since the getDoorData has been changed to use else if
    // instead of independent if blocks (for easy implementation of hasXMid)
    // you will want to rewrite how !BottomLeft and similar are dealt with in 1x1
    // rooms, because 1x1 rooms will not be incorrect on all hasXY
    // but be correct for all hasX (which is sufficient since they can at most have 4 exits)
    DoorData[] doorData;
    foreach(ref room; ms.roomData) {
        auto roomData = getRoomByPoolIndex(room.poolIndex);
        doorData ~= getDoorData(room, roomData);
    }
    int roomIndex = 0;
    foreach(ref room; ms.roomData) {
        auto doors = &doorData[roomIndex];
        auto roomData = getRoomByPoolIndex(room.poolIndex);
        
        string getMatchingDoorCheck(string door)() {
            string xOffset, yOffset;
            bool isVertical;
            string opposite;
            switch(door) {
                case "Top":
                case "TopLeft":
                    yOffset = "-1";
                    xOffset = "0";
                    isVertical = true;
                    opposite = "Bottom";
                    break;
                case "TopMid":
                    yOffset = "-1";
                    xOffset = "1";
                    isVertical = true;
                    opposite = "Bottom";
                    break;
                case "TopRight":
                    yOffset = "-1";
                    xOffset = "roomData.tileWidth - 1";
                    isVertical = true;
                    opposite = "Bottom";
                    break;
                case "Bottom":
                case "BottomLeft":
                    xOffset = "0";
                    yOffset = "roomData.tileHeight";
                    isVertical = true;
                    opposite = "Top";
                    break;
                case "BottomMid":
                    yOffset = "roomData.tileHeight";
                    xOffset = "1";
                    isVertical = true;
                    opposite = "Top";
                    break;
                case "BottomRight":
                    yOffset = "roomData.tileHeight";
                    xOffset = "roomData.tileWidth - 1";
                    isVertical = true;
                    opposite = "Top";
                    break;
                case "Left":
                case "LeftTop":
                    xOffset = "-1";
                    yOffset = "0";
                    opposite = "Right";
                    break;
                case "LeftMid":
                    xOffset = "-1";
                    yOffset = "1";
                    opposite = "Right";
                    break;
                case "LeftBottom":
                    xOffset = "-1";
                    yOffset = "roomData.tileHeight - 1";
                    opposite = "Right";
                    break;
                case "Right":
                case "RightTop":
                    xOffset = "roomData.tileWidth";
                    yOffset = "0";
                    opposite = "Left";
                    break;
                case "RightMid":
                    xOffset = "roomData.tileWidth";
                    yOffset = "1";
                    opposite = "Left";
                    break;
                case "RightBottom":
                    xOffset = "roomData.tileWidth";
                    yOffset = "roomData.tileHeight - 1";
                    opposite = "Left";
                    break;
                default:
                    break;
            }
            // The logic is as follows:
            // You figure out what tile in the room has to have an exit
            // and then you check on the door data if there is an actual exit
            // on that tile. If there is not, then the room we are currently looking at
            // does not have an exit leading to the other room.
            return "
                int xOffset = " ~ xOffset ~ ";
                int yOffset = " ~ yOffset ~ ";
                int matchingRoomIndex = getRoomIndex(room.tileX + xOffset, room.tileY + yOffset);
                if(matchingRoomIndex == -1) {
                    (*doors).has" ~ door ~ " = false;
                    continue;
                }
                    
                auto matchingRoom = ms.roomData[matchingRoomIndex];
                RoomData matchingRoomData = getRoomByBoolIndex(matchingRoom.poolIndex);
                auto matchingDoors = &doorData[matchingRoomIndex];
                " ~ (isVertical ? "
                    int relativeTileX = room.tileX - matchingRoomData.tileX;
                    if(matchingRoomData.tileWidth == 1 && !(*matchingDoors).has" ~ opposite ~ ") {
                        (*doors).has" ~ door ~ " = false;
                    }
                    else if(matchingRoomData.tileWidth == 2) {
                        if(relativeTileX == 0 && !(*matchingDoors).has" ~ opposite ~ "Left) {
                            (*doors).has" ~ door ~ " = false;
                        }
                        else if(relativeTileX == 1 && !(*matchingDoors).has" ~ opposite ~ "Right) {
                            (*doors).has" ~ door ~ " = false;
                        }
                    }
                    else if(matchingRoomData.tileWidth == 3) {
                        if(relativeTileX == 0 && !(*matchingDoors).has" ~ opposite ~ "Left) {
                            (*doors).has" ~ door ~ " = false;
                        }
                        else if(relativeTileX == 1 && !(*matchingDoors).has" ~ opposite ~ "Mid) {
                            (*doors).has" ~ door ~ " = false;
                        }
                        else if(relativeTileX == 2 && !(*matchingDoors).has" ~ opposite ~ "Right) {
                            (*doors).has" ~ door ~ " = false;
                        }
                    }
                    else assert(0);"
                : "
                    int relativeTileY = room.tileY - matchingRoomData.tileY;
                    if(matchingRoomData.tileHeight == 1 && !(*matchingDoors).has" ~ opposite ~ ") {
                        (*doors).has" ~ door ~ " = false;
                    }
                    else if(matchingRoomData.tileHeight == 2) {
                        if(relativeTileY == 0 && !(*matchingDoors).has" ~ opposite ~ "Top) {
                            (*doors).has" ~ door ~ " = false;
                        }
                        else if(relativeTileY == 1 && !(*matchingDoors).has" ~ opposite ~ "Bottom) {
                            (*doors).has" ~ door ~ " = false;
                        }
                    }
                    else if(matchingRoomData.tileHeight == 3) {
                        if(relativeTileY == 0 && !(*matchingDoors).has" ~ opposite ~ "Top) {
                            (*doors).has" ~ door ~ " = false;
                        }
                        else if(relativeTileY == 1 && !(*matchingDoors).has" ~ opposite ~ "Mid) {
                            (*doors).has" ~ door ~ " = false;
                        }
                        else if(relativeTileY == 2 && !(*matchingDoors).has" ~ opposite ~ "Bottom) {
                            (*doors).has" ~ door ~ " = false;
                        }
                    }
                    else assert(0);"
                );
        }
        string doDoorChecks(args...)() {
            string code = "";
            foreach(arg; args) {
                code ~= "if((*doors).has" ~ arg ~ ") {
                    mixin getMatchingDoorCheck!\"" ~ arg ~ "\";
                }
                ";
            }
            return code;
        }
        switch(roomData.tileWidth) {
            case 1:
                if(roomData.tileHeight == 1) {
                    mixin(doDoorChecks!("Top", "Bottom", "Left", "Right"));
                }
                else if(roomData.tileHeight == 2) {
                    mixin(doDoorChecks!("Top", "Bottom", "LeftTop", "LeftBottom", "RightTop", "RightBottom"));
                }
                else if(roomData.tileHeight == 3) {
                    mixin(doDoorChecks!("Top", "Bottom", "LeftTop", "LeftMid", "LeftBottom", "RightTop", "RightMid", "RightBottom"));
                }
                fixInconsistentExits(doors);
                break;
            case 2:
                if(roomData.tileHeight == 1) {
                    mixin(doDoorChecks!("TopLeft", "TopRight", "BottomLeft", "BottomRight", "Left", "Right"));
                }
                else if(roomData.tileHeight == 2) {
                    mixin(doDoorChecks!("TopLeft", "TopRight", "BottomLeft", "BottomRight", "LeftTop", "LeftBottom", "RightTop", "RightBottom"));
                }
                else if(roomData.tileHeight == 3) {
                    mixin(doDoorChecks!("TopLeft", "TopRight", "BottomLeft", "BottomRight", "LeftTop", "LeftMid", "LeftBottom", "RightTop", "RightMid", "RightBottom"));
                }
                fixInconsistentExits(doors);
                break;
            case 3:
                if(roomData.tileHeight == 1) {
                    mixin(doDoorChecks!("TopLeft", "TopMid", "TopRight", "BottomLeft", "BottomMid", "BottomRight", "Left", "Right"));
                }
                else if(roomData.tileHeight == 2) {
                    mixin(doDoorChecks!("TopLeft", "TopMid", "TopRight", "BottomLeft", "BottomMid", "BottomRight", "LeftTop", "LeftBottom", "RightTop", "RightBottom"));
                }
                else if(roomData.tileHeight == 3) {
                    mixin(doDoorChecks!("TopLeft", "TopMid", "TopRight", "BottomLeft", "BottomMid", "BottomRight", "LeftTop", "LeftMid", "LeftBottom", "RightTop", "RightMid", "RightBottom"));
                }
                fixInconsistentExits(doors);
                break;
            default:
                assert(0);
        }
        ++roomIndex;
    }
    roomIndex = 0;
    int enemyIndex = 0;
    int skippedEnemies = 0;
    foreach(ref room; ms.roomData) {
        RoomData roomData = getRoomByPoolIndex(room.poolIndex);
        DoorData doors = doorData[roomIndex];

        foreach(enemy; roomData.enemies) {
            import std.algorithm.searching : canFind;

            string doDoorCheck(string direction)() {
                return "
                    if(canFind(enemy.name, \"!" ~ direction ~ "\")) {
                        if(doors.has" ~ direction ~ ") {
                            ++skippedEnemies;
                            continue;
                        }
                        else {
                            writeln(\"Did not skip enemy named \", enemy.name, \" because doors.has" ~ direction ~ " was false.\");
                        }
                    }
                    else if(!canFind(enemy.name, \"!" ~ direction ~ "\") && canFind(enemy.name, \"" ~ direction ~ "\")) {
                        if(!doors.has" ~ direction ~ ") {
                            ++skippedEnemies;
                            continue;
                        }
                        else {
                            writeln(\"Did not skip enemy named \", enemy.name, \" because doors.has" ~ direction ~ " was true.\");
                        }
                    }
                ";
            }
            mixin(doDoorCheck!"TopLeft");
            mixin(doDoorCheck!"TopRight");
            mixin(doDoorCheck!"Top");
            mixin(doDoorCheck!"BottomLeft");
            mixin(doDoorCheck!"BottomRight");
            mixin(doDoorCheck!"Bottom");
            mixin(doDoorCheck!"LeftTop");
            mixin(doDoorCheck!"LeftBottom");
            mixin(doDoorCheck!"Left");
            mixin(doDoorCheck!"RightTop");
            mixin(doDoorCheck!"RightBottom");
            mixin(doDoorCheck!"Right");

            ms.enemies ~= MapEnemySave(enemy.x - roomData.x + room.x, enemy.y - roomData.y + room.y, enemy.name, enemyTypes[ms.enemyTypes[enemyIndex]], cast(EnemyTier)ms.enemyTiers[enemyIndex]);
            ++enemyIndex;
            if(enemyIndex > ms.numEnemies)
                throw new Error("More enemies in rooms than in mapsave. Total skipped enemies = " ~ skippedEnemies.to!string);
        }
        ++roomIndex;
    }
    writeln("num detected enemies = ", ms.enemies.length);
    writeln("num specified enemies = ", ms.numEnemies);
    //enforce(ms.enemies.length == ms.numEnemies);
    
    return ms;
}
MapDataSave readMapDataSave(string filePath) {
    import std.file;
    auto mapDataBytes = cast(ubyte[])read(filePath);
    
    MapDataSave mapDataSave = MapDataSave();
    mapDataSave.numDiscoveredRooms = *cast(int*)mapDataBytes.ptr;
    mapDataSave.discoveredRooms = cast(bool[])mapDataBytes[int.sizeof .. mapDataSave.numDiscoveredRooms + int.sizeof];
    auto offset = mapDataSave.numDiscoveredRooms + int.sizeof;
    
    mapDataSave.numCompletedBonusRooms = *cast(int*)mapDataBytes[offset .. $].ptr;
    mapDataSave.completedBonusRooms = cast(bool[])mapDataBytes[offset + int.sizeof .. offset + mapDataSave.numCompletedBonusRooms + int.sizeof];
    offset += mapDataSave.numCompletedBonusRooms + int.sizeof;
    mapDataSave.bonusRoomIds = cast(int[])mapDataBytes[offset .. offset + mapDataSave.numCompletedBonusRooms * int.sizeof];
    offset += mapDataSave.numCompletedBonusRooms * int.sizeof;
    
    mapDataSave.numChestTypes = *cast(int*)mapDataBytes[offset .. $].ptr;
    mapDataSave.chestTypes = mapDataBytes[offset + int.sizeof .. offset + mapDataSave.numChestTypes + int.sizeof];
    offset += mapDataSave.numChestTypes + int.sizeof;
    
    mapDataSave.numOpenedChests = *cast(int*)mapDataBytes[offset .. $].ptr;
    mapDataSave.chestTypes = mapDataBytes[offset + int.sizeof .. offset + mapDataSave.numOpenedChests + int.sizeof];
    offset += mapDataSave.numOpenedChests + int.sizeof;
    
    mapDataSave.numUnlockedFairyChests = *cast(int*)mapDataBytes[offset .. $].ptr;
    mapDataSave.chestTypes = mapDataBytes[offset + int.sizeof .. offset + mapDataSave.numUnlockedFairyChests + int.sizeof];
    offset += mapDataSave.numUnlockedFairyChests + int.sizeof;
    
    mapDataSave.numKilledEnemies = *cast(int*)mapDataBytes[offset .. $].ptr;
    mapDataSave.chestTypes = mapDataBytes[offset + int.sizeof .. offset + mapDataSave.numKilledEnemies + int.sizeof];
    offset += mapDataSave.numKilledEnemies + int.sizeof;
    
    mapDataSave.numDestroyedBreakables = *cast(int*)mapDataBytes[offset .. $].ptr;
    mapDataSave.chestTypes = mapDataBytes[offset + int.sizeof .. offset + mapDataSave.numDestroyedBreakables + int.sizeof];
    offset += mapDataSave.numDestroyedBreakables + int.sizeof;
    
    return mapDataSave;
}
