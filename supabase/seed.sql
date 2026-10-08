-- Optional catalogue seed. The asset paths refer to artwork bundled in the app.
-- Run only once in a fresh project, after the migrations.
insert into public.books(title,author,category,published_year,edition,shelf,synopsis,cover_path,copies) values
('Introduction to Algorithms','Thomas H. Cormen','Computer Science',2019,'4th Edition','Shelf B-12, Section 3','A comprehensive guide to the modern study of computer algorithms, presenting many algorithms in detail with mathematical rigor yet remaining widely accessible to all levels of readers.','assets/figma/88bd2.png',3),
('Digital Circuits & Data Pathways','Andrew S. Tanenbaum','Computer Science',2021,'2nd Edition','Shelf A-7, Section 1','An introduction to digital circuits and the organisation of computing systems.','assets/figma/6fea3.png',2),
('Architecting Computing Systems','Erich Gamma','Computer Science',2021,'1st Edition','Shelf A-8, Section 1','A practical overview of computing system architecture.','assets/figma/9df7b.png',2),
('Clean Code','Robert C. Martin','Computer Science',2008,'1st Edition','Shelf B-12, Section 4','A handbook of agile software craftsmanship.','assets/figma/fc70d.png',2),
('Artificial Intelligence','Stuart Russell','Computer Science',2021,'4th Edition','Shelf B-14, Section 2','An introduction to the foundations of artificial intelligence.','assets/figma/99570.png',2);

-- Upload your licensed PDFs through Admin > Add books for live e-books.
-- Demo sample PDFs are included in assets/ebooks; no published full books are bundled.
