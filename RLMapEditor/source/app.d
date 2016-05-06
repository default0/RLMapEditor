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
struct MapSave {
    int mapSize;
    MapRoomSave[] roomData;
    int numEnemies;
    ubyte[] enemyTypes;
    ubyte[] enemyTiers;
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
}
struct RoomData {
    string name;
    int x, y;
    int width, height;
    bool castlePool, forestPool, towerPool, dungeonPool;
    
    RoomObj[] objects;
    Enemy[] enemies;
    
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
        foreach(enemy; enemies) {
            auto proportionalX = cast(double)(enemy.x - x) / cast(double)width;
            auto proportionalY = cast(double)(enemy.y - y) / cast(double)height;
            
            proportionalX = rc.left + (proportionalX * rc.width);
            proportionalY = rc.top + (proportionalY * rc.height);
            buf.fillRect(
                Rect(
                    cast(int)proportionalX,
                    cast(int)proportionalY,
                    cast(int)proportionalX + cast(int)(zoom * 3),
                    cast(int)proportionalY + cast(int)(zoom * 3)
                ),
                0xFF0000
            );
        }
    }
    
    RoomData reverse() {
        auto clone = RoomData(name, x, y, width, height, castlePool, forestPool, towerPool, dungeonPool);
        clone.objects = objects.dup;
        foreach(ref clonedObj; clone.objects) {
            // do the reversal I guess!
            clonedObj.x = width - (clonedObj.x - x) - clonedObj.width + x;
        }
        foreach(ref enemy; clone.enemies) {
            enemy.x = width - (enemy.x - x) + x;
        }
        return clone;
    }
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
        auto basePath = "/home/gregory/.local/share/RogueLegacyStorageContainer/Profile1/";
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
            ["Corrupt Knight", "Corrupt Vanguard", "Corrupt Lord"],
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
            ["Skeleton", "Mr Bones", "McRib"],
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
            ["Bud", "Plantite", "Flowermon"],
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
            ["Training Dummy"],
            30
        ),
        31: EnemyType(
            "Plonky",
            ["Plinky", "Planky", "Plonky"],
            31
        ),
        32: EnemyType(
            "Portrait",
            ["Doomvas", "Doomtrait", "Doomscape"],
            32
        ),
        33: EnemyType(
            "Mimic",
            ["Mimic", "Mimicant", "Mimicrunch"],
            33
        )
    ];
    
        auto mapFilePath = basePath ~ "RogueLegacyMap.rcdat";
        auto mapDataFilePath = basePath ~ "RogueLegacyMapDat.rcdat";
    
        import std.file, std.exception, std.xml;
        auto mapBytes = cast(ubyte[])read(mapFilePath);
    
        auto mapSave = readMapSave(mapFilePath);
        auto mapDataSave = readMapDataSave(mapDataFilePath);
        foreach(mapPath; mapPaths) {
            import std.algorithm : canFind;
            readRooms(mapPath, canFind(mapPath, "DLC")); // Map_DLC1.xml is the last entry, and is a DLC map, which is what we need as second arg
        }
    
        auto sequencedRooms = buildSequencedRoomList();
        return buildMap(mapSave, sequencedRooms, dlcCastlePool, dlcForestPool, dlcTowerPool, dlcDungeonPool);
    }
    catch(Throwable t)
    {
        writeln(t);
        readln();
    }
    assert(0);
}

auto buildMap(MapSave mapSave, RoomData[] sequencedRooms, RoomData[] dlcCastle, RoomData[] dlcForest, RoomData[] dlcTower, RoomData[] dlcDungeon) {
    auto getRoomByPoolIndex(int poolIndex) {
        if(poolIndex < 10000) {
            if(poolIndex >= sequencedRooms.length) {
                writeln("No room with poolIndex ", poolIndex);
                return RoomData();
            }
            return sequencedRooms[poolIndex];
        }
        else if(poolIndex < 20000) {
            if(poolIndex - 10000 >= dlcCastle.length) {
                writeln("No room with poolIndex ", poolIndex);
                return RoomData();
            }
            return dlcCastle[poolIndex - 10000];
        }
        else if(poolIndex < 30000) {
            if(poolIndex - 20000 >= dlcForest.length) {
                writeln("No room with poolIndex ", poolIndex);
                return RoomData();
            }
            return dlcForest[poolIndex - 20000];
        }
        else if(poolIndex < 40000) {
            if(poolIndex - 30000 >= dlcTower.length) {
                writeln("No room with poolIndex ", poolIndex);
                return RoomData();
            }
            return dlcTower[poolIndex - 30000];
        }
        else {
            if(poolIndex - 40000 >= dlcDungeon.length) {
                writeln("No room with poolIndex ", poolIndex);
                return RoomData();
            }
            return dlcDungeon[poolIndex - 40000];
        }
    }
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
        TableLayout propertiesGrid;
        
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
            });
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
                        // find the right room, heh
                        int mouseX = event.x - canvas.pos.left;
                        int mouseY = event.y - canvas.pos.top;
                        // we now have mouse relative to canvas
                        // we now need room rect relative to canvas
                        int tileWidth = cast(int)(26f * zoom);
                        int tileHeight = cast(int)(14f * zoom);
                        
                        foreach(ref room; mapSave.roomData) {
                            RoomData roomData = getRoomByPoolIndex(room.poolIndex);
                            auto gridXHigh = room.tileX + roomData.tileWidth;
                            auto gridYHigh = room.tileY + roomData.tileHeight;
                            
                            Rect roomRect = Rect(
                                room.tileX * tileWidth + cameraX + 2,
                                room.tileY * tileHeight + cameraY + 2,
                                gridXHigh * tileWidth + cameraX,
                                gridYHigh * tileHeight + cameraY
                            );
                            if(mouseX >= roomRect.left && mouseX <= roomRect.right) {
                                if(mouseY >= roomRect.top && mouseY <= roomRect.bottom) {
                                    selectRoom(&room);
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
                            selectRoom(null);
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
                
                switch(event.keyCode) {
                    case 37:
                    case 65:
                        leftDown = targetValue;
                        break;
                    case 38:
                    case 87:
                        upDown = targetValue;
                        break;
                    case 39:
                    case 68:
                        rightDown = targetValue;
                        break;
                    case 40:
                    case 83:
                        downDown = targetValue;
                        break;
                    default:
                        break;
                }
                return true;
            });
            canvas.onDrawListener = delegate(CanvasWidget canvas, DrawBuf buf, Rect rc) {
                buf.fill(0x000000);
                int x = rc.left + cameraX;
                int y = rc.top + cameraY;
                int tileWidth = cast(int)(26f * zoom);
                int tileHeight = cast(int)(14f * zoom);
                
                foreach(ref room; mapSave.roomData) {
                    bool isSelected = false;
                    if(&room == selectedRoom)
                        isSelected = true;
                        
                    RoomData roomData = getRoomByPoolIndex(room.poolIndex);
                    auto gridXHigh = room.tileX + roomData.tileWidth;
                    auto gridYHigh = room.tileY + roomData.tileHeight;
        
                    enum offset = 2;
                    roomData.drawTo(
                        room,
                        buf,
                        Rect(
                            x + room.tileX * tileWidth + offset,
                            y + room.tileY * tileHeight + offset,
                            x + gridXHigh * tileWidth - offset,
                            y + gridYHigh * tileHeight - offset
                        ),
                        isSelected,
                        zoom
                    );
                }
            };
            
            addChild(w);
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
        
        void selectRoom(MapRoomSave* roomPtr) {
            selectedRoom = roomPtr;
            propertiesGrid.removeAllChildren(); // clear whatever the old selection was
            if(selectedRoom is null) {
                return; // no properties to display
            }
            
            // show/update room properties here
            auto text = new TextWidget();
            text.text = "Room Name: " ~ getRoomByPoolIndex((*roomPtr).poolIndex).name.to!dstring;
            text.textColor = propertiesGrid.textColor;
            propertiesGrid.addChild(text);
                
            text = new TextWidget();
            text.text = "Room Id: " ~ (*roomPtr).poolIndex.to!dstring;
            text.textColor = propertiesGrid.textColor;
            propertiesGrid.addChild(text);
                
            text = new TextWidget();
            text.text = "X: " ~ (*roomPtr).x.to!dstring;
            text.textColor = propertiesGrid.textColor;
            propertiesGrid.addChild(text);
                
            text = new TextWidget();
            text.text = "Y: " ~ (*roomPtr).y.to!dstring;
            text.textColor = propertiesGrid.textColor;
            propertiesGrid.addChild(text);
        }
    }
    Window window = Platform.instance.createWindow("Test Window", null);
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
                case "EnemyOrbObj":
                    auto enemy = Enemy();
                    enemy.x = cast(int)to!float(objectMetadata["X"]);
                    enemy.y = cast(int)to!float(objectMetadata["Y"]);
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

auto readMapSave(string filePath) {
    import std.exception, std.file;
    auto mapBytes = cast(ubyte[])read(filePath);
    
    MapSave mapSave = MapSave();
    enforce(mapBytes.length >= 4);
    mapSave.mapSize = *cast(int*)mapBytes.ptr;
    mapSave.roomData = cast(MapRoomSave[])(mapBytes[int.sizeof .. mapSave.mapSize * MapRoomSave.sizeof + int.sizeof]);
    auto enemyDataStart = mapSave.mapSize * MapRoomSave.sizeof + int.sizeof;
    mapSave.numEnemies = *cast(int*)mapBytes[enemyDataStart .. $].ptr;
    mapSave.enemyTypes = mapBytes[enemyDataStart + int.sizeof .. enemyDataStart + int.sizeof + mapSave.numEnemies];
    mapSave.enemyTiers = mapBytes[enemyDataStart + int.sizeof + mapSave.numEnemies .. $];
    enforce(mapSave.enemyTypes.length == mapSave.enemyTiers.length);
    
    return mapSave;
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
