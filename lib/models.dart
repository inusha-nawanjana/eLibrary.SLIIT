import 'dart:convert';

String asset(String name) => 'assets/figma/$name';

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.cover,
    this.detailCover,
    this.status = 'Available',
    this.year = 2021,
    this.edition = '1st Edition',
    this.shelf = 'Shelf B-12, Section 3',
    this.synopsis = defaultSynopsis,
    this.ebook = false,
    this.course = '',
    this.ebookPath,
  });
  final String id,
      title,
      author,
      category,
      cover,
      status,
      edition,
      shelf,
      synopsis,
      course;
  final String? detailCover, ebookPath;
  final int year;
  final bool ebook;
  static const defaultSynopsis =
      'A comprehensive guide to the modern study of computer algorithms, presenting many algorithms in detail with mathematical rigor yet remaining widely accessible to all levels of readers.';
  factory Book.fromJson(Map<String, dynamic> j) => Book(
    id: j['id'],
    title: j['title'],
    author: j['author'],
    category: j['category'],
    cover: j['cover_path'] ?? '',
    year: j['published_year'] ?? 2021,
    edition: j['edition'] ?? '',
    shelf: j['shelf'] ?? '',
    synopsis: j['synopsis'] ?? '',
    ebook: j['ebook_path'] != null,
    ebookPath: j['ebook_path'],
    status: j['status'] ?? 'Available',
  );
}

class LibraryRoom {
  const LibraryRoom(this.id, this.kind, this.number, {this.occupied = false});
  final String id, kind;
  final int number;
  final bool occupied;
  String get title =>
      '${kind == 'learning' ? 'Learning' : 'Discussion'} Room $number';
  int get capacity => kind == 'learning' ? 6 : 9;
  String get cover => asset(kind == 'learning' ? 'b4bff.png' : '7d7f8.png');
}

class Booking {
  Booking({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.date,
    this.itemId = '',
    this.start,
    this.end,
    this.note = '',
    this.extensionPending = false,
  });
  final String id, kind, title, subtitle, itemId;
  String status, note;
  DateTime date;
  DateTime? start, end;
  bool extensionPending;
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'title': title,
    'subtitle': subtitle,
    'status': status,
    'date': date.toIso8601String(),
    'itemId': itemId,
    'start': start?.toIso8601String(),
    'end': end?.toIso8601String(),
    'note': note,
    'extensionPending': extensionPending,
  };
  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
    id: j['id'],
    kind: j['kind'],
    title: j['title'],
    subtitle: j['subtitle'],
    status: j['status'],
    date: DateTime.parse(j['date']),
    itemId: j['itemId'] ?? '',
    start: j['start'] == null ? null : DateTime.parse(j['start']),
    end: j['end'] == null ? null : DateTime.parse(j['end']),
    note: j['note'] ?? '',
    extensionPending: j['extensionPending'] ?? false,
  );
}

class LibraryNotice {
  LibraryNotice(
    this.id,
    this.title,
    this.body,
    this.category, {
    this.read = false,
  });
  final String id, title, body, category;
  bool read;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'category': category,
    'read': read,
  };
  factory LibraryNotice.fromJson(Map<String, dynamic> j) => LibraryNotice(
    j['id'],
    j['title'],
    j['body'],
    j['category'],
    read: j['read'] ?? false,
  );
}

List<Map<String, dynamic>> decodeRows(String? value) => value == null
    ? []
    : (jsonDecode(value) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

const categoryNames = [
  'Computer Science',
  'Management',
  'Law',
  'Cookery',
  'Data Science',
  'Engineering',
];
const categoryAssets = [
  'aa226.png',
  '6350b.png',
  'c406c.png',
  '8dbb5.png',
  '4412b.png',
  '19b07.png',
];
const slots = [9, 11, 13, 15];
String slotLabel(int hour) =>
    '${hour.toString().padLeft(2, '0')}:00 - ${(hour + 2).toString().padLeft(2, '0')}:00';
String dateLabel(DateTime d) =>
    '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.day}, ${d.year}';
DateTime get campusNow =>
    DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
DateTime campusUtc(DateTime day, int hour) => DateTime.utc(
  day.year,
  day.month,
  day.day,
  hour,
).subtract(const Duration(hours: 5, minutes: 30));
DateTime campusDate(DateTime utc) =>
    utc.toUtc().add(const Duration(hours: 5, minutes: 30));

List<Book> demoBooks() => [
  Book(
    id: 'algorithms',
    title: 'Introduction to Algorithms',
    author: 'Thomas H. Cormen',
    category: 'Computer Science',
    cover: asset('964c1.png'),
    detailCover: asset('88bd2.png'),
    year: 2019,
    edition: '4th Edition',
  ),
  Book(
    id: 'circuits',
    title: 'Digital Circuits & Data Pathways',
    author: 'Andrew S. Tanenbaum',
    category: 'Computer Science',
    cover: asset('6fea3.png'),
    status: 'Reserved',
    shelf: 'Shelf A-7, Section 1',
  ),
  Book(
    id: 'systems',
    title: 'Architecting Computing Systems',
    author: 'Erich Gamma',
    category: 'Computer Science',
    cover: asset('9df7b.png'),
    status: 'Checked Out',
  ),
  Book(
    id: 'clean',
    title: 'Clean Code',
    author: 'Robert C. Martin',
    category: 'Computer Science',
    cover: asset('fc70d.png'),
  ),
  Book(
    id: 'ai',
    title: 'Artificial Intelligence',
    author: 'Stuart Russell',
    category: 'Computer Science',
    cover: asset('99570.png'),
  ),
  for (final title in [
    'Java: A Beginner’s Guide',
    'Computer Networking',
    'Database Systems',
    'Design Patterns',
    'Learning Python',
    'Operating Systems',
    'Data Structures & Algorithms',
    'Introduction to ML',
    'Software Engineering',
  ])
    Book(
      id: title.toLowerCase().replaceAll(' ', '-'),
      title: title,
      author: 'SLIIT Library Collection',
      category: 'Computer Science',
      cover: asset('9df7b.png'),
    ),
  Book(
    id: 'management',
    title: 'Financial Overview',
    author: 'SLIIT Business School',
    category: 'Management',
    cover: asset('b252e.png'),
  ),
  Book(
    id: 'law',
    title: 'Corpus Juris Secundum',
    author: 'Legal Studies Collection',
    category: 'Law',
    cover: asset('76838.png'),
  ),
  Book(
    id: 'cookery',
    title: 'The Pie and Pastry Bible',
    author: 'Rose Levy Beranbaum',
    category: 'Cookery',
    cover: asset('8af99.png'),
  ),
  Book(
    id: 'data',
    title: 'Big Data & Hadoop',
    author: 'Alexander Reed',
    category: 'Data Science',
    cover: asset('5b55c.png'),
  ),
  Book(
    id: 'engineering',
    title: 'Digital Systems Engineering',
    author: 'SLIIT Engineering Collection',
    category: 'Engineering',
    cover: asset('6fea3.png'),
  ),
  Book(
    id: 'ebook-hadoop',
    title: 'Big Data & Hadoop',
    author: 'Alexander Reed',
    category: 'Data Science',
    cover: asset('5b55c.png'),
    ebook: true,
    course: 'IT-801',
    ebookPath: 'assets/ebooks/hadoop.pdf',
  ),
  Book(
    id: 'ebook-finance',
    title: 'Financial Overview',
    author: 'SLIIT Business School',
    category: 'Management',
    cover: asset('b252e.png'),
    ebook: true,
    course: 'BM-204',
    ebookPath: 'assets/ebooks/finance.pdf',
  ),
  Book(
    id: 'ebook-law',
    title: 'Corpus Juris Secundum',
    author: 'Legal Studies Collection',
    category: 'Law',
    cover: asset('76838.png'),
    ebook: true,
    course: 'LW-102',
    ebookPath: 'assets/ebooks/law.pdf',
  ),
  Book(
    id: 'ebook-pastry',
    title: 'The Pie and Pastry Bible',
    author: 'Rose Levy Beranbaum',
    category: 'Cookery',
    cover: asset('8af99.png'),
    ebook: true,
    course: 'CK-502',
    ebookPath: 'assets/ebooks/pastry.pdf',
  ),
];

List<Booking> demoBookings() {
  final day = campusNow;
  return [
    Booking(
      id: 'sample-1',
      kind: 'book',
      title: 'Data Structures & Algorithms',
      subtitle: 'Author: Mark Allen Weiss',
      status: 'Pending',
      date: day.subtract(const Duration(days: 2)),
    ),
    Booking(
      id: 'sample-2',
      kind: 'book',
      title: 'Introduction to ML',
      subtitle: 'Author: Ethem Alpaydin',
      status: 'Approved',
      date: day.subtract(const Duration(days: 3)),
    ),
    Booking(
      id: 'sample-3',
      kind: 'book',
      title: 'Clean Code',
      subtitle: 'Author: Robert C. Martin',
      status: 'Active',
      date: day.add(const Duration(days: 3)),
      itemId: 'clean',
    ),
    Booking(
      id: 'sample-4',
      kind: 'book',
      title: 'Database Systems',
      subtitle: 'Author: Abraham Silberschatz',
      status: 'Completed',
      date: day.subtract(const Duration(days: 10)),
    ),
    for (final kind in ['learning', 'discussion']) ...[
      Booking(
        id: '$kind-1',
        kind: kind,
        title: kind == 'learning' ? 'Learning Room 3' : 'Discussion Room 2',
        subtitle: kind == 'learning'
            ? 'Capacity: 4 People'
            : 'Capacity: 8 People',
        status: kind == 'learning' ? 'Pending' : 'Approved',
        date: day,
        start: campusUtc(day, 13),
        end: campusUtc(day, 15),
      ),
      Booking(
        id: '$kind-2',
        kind: kind,
        title: kind == 'learning' ? 'Learning Room 7' : 'Discussion Room 5',
        subtitle: kind == 'learning'
            ? 'Capacity: 3 People'
            : 'Capacity: 6 People',
        status: 'Active',
        date: day.add(const Duration(days: 1)),
        start: campusUtc(day.add(const Duration(days: 1)), 9),
        end: campusUtc(day.add(const Duration(days: 1)), 11),
        itemId: '$kind-${kind == 'learning' ? 7 : 5}',
      ),
      Booking(
        id: '$kind-3',
        kind: kind,
        title: kind == 'learning' ? 'Learning Room 1' : 'Discussion Room 1',
        subtitle: kind == 'learning'
            ? 'Capacity: 4 People'
            : 'Capacity: 10 People',
        status: 'Completed',
        date: day.subtract(const Duration(days: 8)),
      ),
    ],
  ];
}

List<LibraryNotice> demoNotices() => [
  LibraryNotice(
    'n1',
    'Just Arrived: Oracle Database Engineering',
    'Physical copies of Advanced Oracle Object SQL are now available in the Computer Science collection.',
    'updates',
  ),
  LibraryNotice(
    'n2',
    'Book Ready for Pickup',
    'Your reserved copy of Design Patterns is ready. Please collect it from the library within 48 hours.',
    'reservations',
  ),
  LibraryNotice(
    'n3',
    'Reservation Cancelled',
    'Your reservation for The Elements of Style has been cancelled. You can submit a new request from the catalogue.',
    'reservations',
  ),
  LibraryNotice(
    'n4',
    'Resource Update: UI/UX Design Trends',
    'The latest edition of Responsive Mobile Artboards has been added to the digital collection.',
    'updates',
  ),
  LibraryNotice(
    'n5',
    'Return Reminder: Computer Networking',
    'Your borrowed item Computer Networking: A Top-Down Approach is due soon. Check Your Activity for details.',
    'reservations',
  ),
];

const hadoopPreview =
    'Hadoop is an open-source framework managed by the Apache Software Foundation that allows for the distributed processing of large datasets across clusters of computers using simple programming models. It is designed to scale up from single servers to thousands of machines, each offering local computation and storage.\n\nRather than relying on hardware to deliver high-availability, the library itself is designed to detect and handle failures at the application layer...';
const hadoopFull =
    '$hadoopPreview so delivering a highly-available service on top of a cluster of computers, each of which may be prone to hardware degradation or system crashes.\n\nAt the core of this framework are two fundamental components: the Hadoop Distributed File System (HDFS) and the MapReduce programming model. HDFS handles the storage layer by breaking massive datasets into smaller, manageable blocks and distributing them across the various nodes within the cluster. To ensure data reliability and fault tolerance, these blocks are automatically replicated across different machines, safeguarding the system against isolated node failures.\n\nOnce the data is securely distributed, the MapReduce engine takes over the processing. Instead of moving massive amounts of data to a central processing unit, MapReduce sends the computing logic directly to the nodes where the data currently resides. It divides complex analytical queries into smaller, parallel tasks (the Map phase) and then aggregates the results (the Reduce phase), which drastically minimizes network congestion and accelerates processing times.';
