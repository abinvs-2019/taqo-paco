import 'package:flutter/material.dart';
import 'package:taqo_client/model/experiment.dart';
import 'package:taqo_client/pages/running_experiments_page.dart';
import 'package:flutter_html_view/flutter_html_view.dart';

class PostJoinInstructionsPage extends StatefulWidget {
  static const routeName = '/post_join_instructions';

  PostJoinInstructionsPage({Key key}) : super(key: key);

  @override
  _PostJoinInstructionsPageState createState() => _PostJoinInstructionsPageState();
}


class _PostJoinInstructionsPageState extends State<PostJoinInstructionsPage> {

  @override
  Widget build(BuildContext context) {
    Experiment experiment = ModalRoute.of(context).settings.arguments;
    return Scaffold(
      appBar: AppBar(
        title: Text(experiment.title + " Instructions"),
        backgroundColor: Colors.indigo,
      ),
      body: Container(
        padding: EdgeInsets.all(8.0),
        //margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            buildinstructionsColumn(experiment),
          ],
        ),
      ),
        floatingActionButton: FloatingActionButton(
            child: Icon(Icons.done),
            onPressed: () {
          Navigator.pushReplacementNamed(context, RunningExperimentsPage.routeName);
        })
    );
  }


  Widget buildinstructionsColumn(experiment) {
    return Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text("Post Join Instructions", style: TextStyle(fontWeight: FontWeight.bold),),
          Divider(
            height: 16.0,
            color: Colors.black,
          ),
          Expanded(child: HtmlView(data: experiment.postInstallInstructions != null ? experiment.postInstallInstructions : "No further instructions provided")),
        ]));
  }

}