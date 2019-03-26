import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'configs.dart';
import 'package:http/http.dart' as http;

Future<List<Game>> fetchOwnedGames() async {
  final response = 
    await http.get('http://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key=${Configs.APIKey}&steamid=${Configs.SteamID}&include_appinfo=1&include_played_free_games=1');

  if(response.statusCode == 200){
    final responseBody = json.decode(response.body);
    List<Game> ownedGames = List<Game>();
    for(final gameJson in responseBody['response']['games']){
      var tempGame = Game.fromJson(gameJson);
      

      // get achievements for game
      final achievementsResponse = await http.get("http://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v0001/?appid=${tempGame.appid}&key=${Configs.APIKey}&steamid=${Configs.SteamID}");
      if(achievementsResponse.statusCode == 200){
        final achievementResponseBody = json.decode(achievementsResponse.body);
        if(achievementResponseBody.containsKey('playerstats') && achievementResponseBody['playerstats'].containsKey('achievements')){
          var totalAchievements = (achievementResponseBody['playerstats']['achievements']).length;
          var totalAchieved = (achievementResponseBody['playerstats']['achievements']).where((a) => a['achieved'].toString() == '1').length;
          tempGame.totalAchievements = totalAchievements;
          tempGame.unlockedAchievements = totalAchieved;
          tempGame.unlockedPercentage = totalAchievements > 0 ? (totalAchieved / totalAchievements * 1.0) : 0.0;
        }
      }
      ownedGames.add(tempGame);
    }
    ownedGames.sort((x, y) => y.unlockedPercentage.compareTo(x.unlockedPercentage));
    return ownedGames.where((x) => x.unlockedPercentage < 1.0).take(10).toList();

  }else{
    throw Exception('Error making request to Steam API');
  }
}

Future<List<Achievement>> fetchAchievementsForGame(int appid) async{
  final response = await http.get('http://api.steampowered.com/ISteamUserStats/GetSchemaForGame/v2/?appid=${appid}&key=${Configs.APIKey}');
  final achievementsResponse = await http.get('http://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v0001/?appid=${appid}&key=${Configs.APIKey}&steamid=${Configs.SteamID}');

  if(response.statusCode == 200 && achievementsResponse.statusCode == 200){
    final responseBody = json.decode(response.body);
    final achievementBody = json.decode(achievementsResponse.body);

    // parse achieved into its own array
    List<Achievement> completedAchievements = List<Achievement>();
    if(achievementBody.containsKey('playerstats') && achievementBody['playerstats'].containsKey('achievements')){
      for(final achievementJson in achievementBody['playerstats']['achievements']){
        Achievement tempAchievement = Achievement.fromJson(achievementJson);
        if(tempAchievement.achieved == 1){
          completedAchievements.add(tempAchievement);
        }
      }
    }

    List<Achievement> gameAchievements = List<Achievement>();
    if(responseBody.containsKey('game') && responseBody['game'].containsKey('availableGameStats') && responseBody['game']['availableGameStats'].containsKey('achievements')){
      for(final achievementJson in responseBody['game']['availableGameStats']['achievements']){
        Achievement tempAchievement =Achievement.fromJson(achievementJson);

        // check if this achievement exists in the achieved section.
        Achievement completedAchievement =completedAchievements.firstWhere((a) => a.apiname ==tempAchievement.apiname, orElse: () => null);
        // Achievement completedAchievement =completedAchievements.firstWhere(((a) => a.apiname ==tempAchievement.apiname), () => null);
        if(completedAchievement != null){
          tempAchievement.achieved = completedAchievement.achieved;
          tempAchievement.unlocktime = completedAchievement.unlocktime;
        }
        else{
          tempAchievement.achieved = 0;
          tempAchievement.unlocktime = 0;
        }
        gameAchievements.add(tempAchievement);
      }
    }
    
    // sort first by unlock time descending
    gameAchievements.sort((x,y) => y.unlocktime.compareTo(x.unlocktime));
    // then by achieved or not ascending
    gameAchievements.sort((x,y) => x.achieved.compareTo(y.achieved));
    return gameAchievements;

  }else{
    throw Exception('Error getting list of achievements from Steam API, Game app id: ${appid}');
  }
}

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steam Achievements Tracker',
      home: SteamAchievementsTracker(),
      routes: <String, WidgetBuilder>{
        '/getID': (BuildContext context) => new GetIDPage(),
        '/achievementList': (BuildContext context) => new SteamAchievementsTracker()
      }
    );
  }
}

class SteamAchievementsTracker extends StatefulWidget{
  @override
  State<SteamAchievementsTracker> createState(){
    if(Configs.SteamID != "" && Configs.SteamID != null){ 
      return new SteamAchievementState();
    }
    // if the steam id is blank, use state to get value instead
    else{
      return new GetSteamIDState();
    }
  }
}

class GetIDPage extends StatefulWidget{
  @override
  State<SteamAchievementsTracker> createState(){
    return new GetSteamIDState();
  }
}

class GetSteamIDState extends State<SteamAchievementsTracker>{
  @override
  String vanityURL = '';
  String steamID = '';

  Widget build(BuildContext context){
    return Scaffold(
      body: Container(
        alignment: AlignmentDirectional.center,
        child:  Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          // new Padding(padding: EdgeInsets.only(top: 140.0),),
          new Text('Enter Steam Vanity URL:'),
          new TextField(
            onChanged: (value){
              vanityURL = value;
              this.setState(()=> vanityURL = value);
            },
            // validator: (value){
            // if(value.isEmpty){
            //   return 'Please enter a value';
            // }
          //}
          ),
          new RaisedButton(
            child: Text('Submit'),
            onPressed: ()async {
              if(vanityURL != null && vanityURL != ''){
                final getIDResponse = await http.get('http://api.steampowered.com/ISteamUser/ResolveVanityURL/v0001?key=${Configs.APIKey}&vanityURL=${vanityURL}&format=json');
                if(getIDResponse.statusCode == 200){
                  // deserialize response
                  final responseBody = json.decode(getIDResponse.body);
                  // set the url in the config object
                  if(responseBody.containsKey('response') && responseBody['response'].containsKey('steamid') && responseBody['response']['steamid'] != '' && responseBody['response']['steamid'] != null){
                    Configs.SteamID =responseBody['response']['steamid'];

                    // use the navigator to go to the main screen
                    this.setState(()=> steamID = Configs.SteamID);
                    Navigator.pushReplacementNamed(context, '/achievementList');
                  }
                }
              }
            },
            )
          
        ],)
        )
    );
  }
}

class SteamAchievementState extends State<SteamAchievementsTracker>{
  @override
  final _ownedGames = <dynamic>[];
  final _achievedGames = <String>[];
  
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text('Steam Achievements Tracker'),
        actions: <Widget>[
          new IconButton(icon: const Icon(Icons.list))
        ],
      ),
      body: _buildAchievements()
    );
  }
  Widget _buildAchievements(){
    return FutureBuilder<List<Game>>(
      future: fetchOwnedGames(),
      builder: (context, snapshot){
        if(snapshot.hasData){
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemBuilder: (context, i){
              if(i.isOdd) return Divider();

              final index = i ~/2;
              if(index < snapshot.data.length){
              return _buildRow(snapshot.data[index]);
              }
            },
          );
        }
        else if(snapshot.hasError){
          return Text("${snapshot.error}");
        }

        // by default, show a loading spinner
        return Container(
          alignment: AlignmentDirectional.center,
          child: CircularProgressIndicator(),
        );
        // return CircularProgressIndicator();
      },
    );
  }
  Widget _buildRow(Game game){
    return ListTile(
      leading: Image.network("http://media.steampowered.com/steamcommunity/public/images/apps/${game.appid}/${game.img_icon_url}.jpg"),
      title: Text(
        game.name + " " + (game.unlockedPercentage * 100).round().toString() + "%"),
      subtitle: Text( "${game.unlockedAchievements} out of ${game.totalAchievements}"),
      onTap: (){
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AchievementDetailState(game: game)
          ));
      },
    );
  }

}

class AchievementDetailState extends StatelessWidget{
  @override
  Game game;

  AchievementDetailState({@required this.game});

  Widget build (BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text('${game.name} Achievements'),
        actions: <Widget>[
          new IconButton(icon: const Icon(Icons.list))
        ],
      ),
      body: _buildAchievementList(game.appid)
    );
  }

  Widget _buildAchievementList(int appID){
    return FutureBuilder<List<Achievement>>(
      future: fetchAchievementsForGame(appID),
      builder: (context, snapshot){
        if(snapshot.hasData){
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemBuilder: (context, i){
              if(i.isOdd) return Divider();

              final index = i ~/2;
              if(index < snapshot.data.length){
                return _buildAchievementRow(snapshot.data[index]);
              }
            },
          );
        }
        else if (snapshot.hasError){
          return Text('${snapshot.error}');
        }

        // by default show a loading spinner
        return Container(
          alignment: AlignmentDirectional.center,
          child: CircularProgressIndicator(),
        );
      }
    );
  }

  Widget _buildAchievementRow(Achievement achievement){
    return ListTile(
      leading: achievement.iconURL != null ? Image.network(achievement.iconURL): null,
      title: Text('${achievement.name}'),
      subtitle: Text('${achievement.description} ${achievement.achieved == 1 ? '\n Unlocked:' + achievement.unlocktime.toString() : ''}'),
    );
  }
}

class Game{
  final int appid;
  final String name;
  final int playtime_forever;
  final String img_icon_url;
  final String img_logo_url;
  int totalAchievements;
  int unlockedAchievements;
  double unlockedPercentage;
  List<Achievement> achievements;

  Game({this.appid, this.name, this.playtime_forever, this.img_icon_url, this.img_logo_url, this.totalAchievements, this.unlockedAchievements, this.unlockedPercentage, this.achievements});

  factory Game.fromJson(Map<String, dynamic>json){
    return Game(
      appid: json['appid'],
      name: json['name'],
      playtime_forever: json['playtime_forever'],
      img_icon_url: json['img_icon_url'],
      img_logo_url: json['img_logo_url'],
      totalAchievements: 0,
      unlockedAchievements: 0,
      unlockedPercentage: 0.0,
      achievements: List<Achievement>()
    );
  }
}

class Achievement{
  final String apiname;
  int achieved;
  int unlocktime;
  final String name;
  final String description;
  final String iconURL;
  final String iconGrayURL;

  Achievement({this.apiname, this.achieved, this.unlocktime, this.name, this.description, this.iconURL, this.iconGrayURL});

  factory Achievement.fromJson(Map<String, dynamic>json){
    return Achievement(
      apiname: json['apiname'] ?? json['name'],
      achieved: json['achieved'],
      unlocktime: json['unlocktime'],
      name: json['displayName'],
      description: json['description'],
      iconURL: json['icon'],
      iconGrayURL: json['icongray']
    );
  }

}