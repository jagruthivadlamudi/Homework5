import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const QuizApp());
}

class QuizApp extends StatelessWidget {
  const QuizApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Customizable Quiz App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const QuizSetupScreen(),
    );
  }
}

class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({Key? key}) : super(key: key);

  @override
  _QuizSetupScreenState createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  int _numberOfQuestions = 5;
  String? _selectedCategory;
  String? _selectedDifficulty;
  String? _selectedType;
  List<dynamic>? _categories;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final response =
        await http.get(Uri.parse('https://opentdb.com/api_category.php'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _categories = data['trivia_categories'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Setup')),
      body: _categories == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    decoration:
                        const InputDecoration(labelText: 'Number of Questions'),
                    value: _numberOfQuestions,
                    items: [5, 10, 15]
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text('$e')))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _numberOfQuestions = value!),
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories!
                        .map((category) => DropdownMenuItem(
                              value: category['id'].toString(),
                              child: Text(category['name']),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value),
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Difficulty'),
                    items: ['easy', 'medium', 'hard']
                        .map((difficulty) => DropdownMenuItem(
                            value: difficulty, child: Text(difficulty)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedDifficulty = value),
                  ),
                  DropdownButtonFormField<String>(
                    decoration:
                        const InputDecoration(labelText: 'Question Type'),
                    items: ['multiple', 'boolean']
                        .map((type) =>
                            DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedType = value),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizScreen(
                            numberOfQuestions: _numberOfQuestions,
                            category: _selectedCategory,
                            difficulty: _selectedDifficulty,
                            type: _selectedType,
                          ),
                        ),
                      );
                    },
                    child: const Text('Start Quiz'),
                  ),
                ],
              ),
            ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final int numberOfQuestions;
  final String? category;
  final String? difficulty;
  final String? type;

  const QuizScreen({
    required this.numberOfQuestions,
    this.category,
    this.difficulty,
    this.type,
    Key? key,
  }) : super(key: key);

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<dynamic>? _questions;
  int _currentIndex = 0;
  int _score = 0;
  int _timeRemaining = 10;
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    final url = Uri.parse(
        'https://opentdb.com/api.php?amount=${widget.numberOfQuestions}'
        '&category=${widget.category ?? ''}'
        '&difficulty=${widget.difficulty ?? ''}'
        '&type=${widget.type ?? ''}');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['results'] != null && data['results'].isNotEmpty) {
        setState(() {
          _questions = data['results'];
          _isLoading = false;
          _startTimer();
        });
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _timeRemaining = 10);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        setState(() => _timeRemaining--);
      } else {
        _nextQuestion(false, "Time's up!");
      }
    });
  }

  void _nextQuestion(bool answeredCorrectly, [String feedback = '']) {
    if (answeredCorrectly) _score++;
    if (_currentIndex + 1 < _questions!.length) {
      setState(() {
        _currentIndex++;
        _startTimer();
      });
    } else {
      _endQuiz();
    }
    if (feedback.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(feedback)));
    }
  }

  void _endQuiz() {
    _timer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizSummary(
          score: _score,
          totalQuestions: _questions!.length,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final question = _questions![_currentIndex];
    final answers = [
      ...question['incorrect_answers'],
      question['correct_answer']
    ]..shuffle();

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentIndex + 1}/${_questions!.length}'),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions!.length),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              question['question'],
              style: const TextStyle(fontSize: 18),
            ),
          ),
          Text('Time Remaining: $_timeRemaining seconds'),
          ...answers.map((answer) {
            return ElevatedButton(
              onPressed: () => _nextQuestion(
                  answer == question['correct_answer'],
                  answer == question['correct_answer']
                      ? 'Correct!'
                      : 'Incorrect! Correct answer: ${question['correct_answer']}'),
              child: Text(answer),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class QuizSummary extends StatelessWidget {
  final int score;
  final int totalQuestions;

  const QuizSummary({
    required this.score,
    required this.totalQuestions,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Summary')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Score: $score/$totalQuestions'),
            ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const QuizSetupScreen()),
                  (route) => false,
                );
              },
              child: const Text('Retake Quiz'),
            ),
          ],
        ),
      ),
    );
  }
}
