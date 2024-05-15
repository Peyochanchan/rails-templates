// Import necessary modules
import defaultTheme from 'tailwindcss/defaultTheme';
import formsPlugin from '@tailwindcss/forms';
import aspectRatioPlugin from '@tailwindcss/aspect-ratio';
import typographyPlugin from '@tailwindcss/typography';
import containerQueriesPlugin from '@tailwindcss/container-queries';
import flowBitePlugin from 'flowbite/plugin';

// import colors from 'tailwindcss/colors';

// Export the configuration using ESM syntax
export default {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/application.tailwind.css',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}',
    "./node_modules/flowbite/**/*.js"
  ],
  theme: {
    // colors: {
    //   transparent: 'transparent',
    //   current: 'currentColor',
    //   black: colors.black,
    //   white: colors.white,
    //   gray: colors.slate,
    //   green: colors.emerald,
    //   purple: colors.violet,
    //   yellow: colors.amber,
    //   pink: colors.fuchsia,
    // },
    extend: {},
  },
  plugins: [
    formsPlugin,
    aspectRatioPlugin,
    typographyPlugin,
    containerQueriesPlugin
    flowBitePlugin
  ]
};
