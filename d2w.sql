# This set of instructions was updated by 9seeds.com based on
# a post by Mike Smullin at mikesmullin.com
#
# Mike's original post can be found here: 
# http://www.mikesmullin.com/development/migrate-convert-import-drupal-5-to-wordpress-27/
#
# 9seeds' updated post can be found here: 
# http://9seeds.com/news/drupal-to-wordpress-migration


# Clear all existing WordPress content
TRUNCATE TABLE wordpress.wp_comments;
TRUNCATE TABLE wordpress.wp_links;
TRUNCATE TABLE wordpress.wp_postmeta;
TRUNCATE TABLE wordpress.wp_posts;
TRUNCATE TABLE wordpress.wp_term_relationships;
TRUNCATE TABLE wordpress.wp_term_taxonomy;
TRUNCATE TABLE wordpress.wp_terms;

# Create Categories
INSERT INTO wordpress.wp_terms (term_id, `name`, slug, term_group)
SELECT
 d.tid, d.name, REPLACE(LOWER(d.name), ' ', '_'), 0
FROM drupal.term_data d
INNER JOIN drupal.term_hierarchy h
 USING(tid);

# Add Taxonomies
INSERT INTO wordpress.wp_term_taxonomy (term_id, taxonomy, description, parent)
SELECT
 d.tid `term_id`,
 'category' `taxonomy`,
 d.description `description`,
 h.parent `parent`
FROM drupal.term_data d
INNER JOIN drupal.term_hierarchy h
 USING(tid);

# Import posts/pages
# POSTS
# Keeps private posts hidden.
INSERT INTO wordpress.wp_posts
	(id, post_author, post_date, post_content, post_title, post_excerpt,
	post_name, post_modified, post_type, `post_status`)
	SELECT DISTINCT
		n.nid `id`,
		n.uid `post_author`,
		FROM_UNIXTIME(n.created) `post_date`,
		r.body `post_content`,
		n.title `post_title`,
		r.teaser `post_excerpt`,
		IF(SUBSTR(a.dst, 11, 1) = '/', SUBSTR(a.dst, 12), a.dst) `post_name`,
		FROM_UNIXTIME(n.changed) `post_modified`,
		n.type `post_type`,
		IF(n.status = 1, 'publish', 'private') `post_status`
	FROM drupal.node n
	INNER JOIN drupal.node_revisions r
		USING(vid)
	LEFT OUTER JOIN drupal.url_alias a
		ON a.src = CONCAT('node/', n.nid)
	# Add more Drupal content types below if applicable.
	WHERE n.type IN ('post', 'page', 'blog', 'story')
;

# Turn articles in to posts
# Add more Drupal content types below if applicable.
UPDATE wordpress.wp_posts
	SET post_type = 'post'
	WHERE post_type IN ('blog', 'story')
;

# Add post to category relationships
INSERT INTO wordpress.wp_term_relationships (object_id, term_taxonomy_id)
SELECT nid, tid FROM drupal.term_node;

# Update category count
UPDATE wordpress.wp_term_taxonomy tt
SET `count` = (
 SELECT COUNT(tr.object_id)
 FROM wordpress.wp_term_relationships tr
 WHERE tr.term_taxonomy_id = tt.term_taxonomy_id);


# Import comments
INSERT INTO wordpress.wp_comments (comment_post_ID, comment_date, comment_content, comment_parent, comment_author, comment_author_email, comment_author_url, comment_approved)
SELECT nid, FROM_UNIXTIME(timestamp), comment, thread, name, mail, homepage, status FROM drupal.comments;

# Update comment counts
USE wordpress;
UPDATE `wp_posts` SET `comment_count` = (SELECT COUNT(`comment_post_id`) FROM `wp_comments` WHERE `wp_posts`.`id` = `wp_comments`.`comment_post_id`);

# Fix breaks in post content
UPDATE wordpress.wp_posts SET post_content = REPLACE(post_content, '', '');

# fix images in post content
UPDATE wordpress.wp_posts SET post_content = REPLACE(post_content, '"/files/', '"/wp-content/uploads/');